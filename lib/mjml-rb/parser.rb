require "nokogiri"
require "uri"
require_relative "options"

require_relative "node_compat"

module MjmlRb
  class Parser
    HTML_VOID_TAGS = %w[area base br col embed hr img input link meta param source track wbr].freeze

    ParseResult = Struct.new(:ast, :diagnostics, :dependencies, keyword_init: true)

    # mj-table retains structural access for its attribute normalization.
    STRUCTURAL_ENDING_TAGS = %w[mj-table mj-carousel-image].freeze

    VOID_TAG_CLOSING_BR_RE = %r{</br\s*>}i.freeze
    VOID_TAG_CLOSING_OTHER_RE = /<\/(#{(HTML_VOID_TAGS - ["br"]).join("|")})\s*>/i.freeze
    VOID_TAG_OPEN_RE = /<(#{HTML_VOID_TAGS.join("|")})(\s[^<>]*?)?>/i.freeze
    BARE_AMPERSAND_RE = /&(?!(?:#[0-9]+|#x[0-9a-fA-F]+|[a-zA-Z][a-zA-Z0-9]*);)/.freeze
    ROOT_LEVEL_HEAD_TAGS = %w[
      mj-attributes
      mj-breakpoint
      mj-html-attributes
      mj-font
      mj-preview
      mj-style
      mj-title
    ].freeze

    class ParseError < StandardError
      attr_reader :line, :file, :dependencies

      def initialize(message, line: nil, file: nil, dependencies: [])
        super(message)
        @line = line
        @file = file
        @dependencies = dependencies
      end
    end

    # Errors collected during include expansion (missing files, etc.)
    # Read after calling #parse to retrieve non-fatal include issues.
    attr_reader :include_errors, :dependencies

    def parse_result(mjml, options = {})
      worker = self.class.new
      ast = worker.parse(mjml, options)
      ParseResult.new(ast: ast, diagnostics: worker.include_errors.freeze, dependencies: worker.dependencies.uniq.freeze)
    end

    def parse(mjml, options = {})
      @include_errors = []
      @dependencies = []
      @ending_tags = @ending_tag_open_re = nil
      opts = normalize_options(options)
      xml = apply_preprocessors(mjml.to_s, opts[:preprocessors])
      xml = wrap_ending_tags_in_cdata(xml)
      xml = outside_cdata(xml) { |part| normalize_html_void_tags(part) }
      xml = expand_includes(xml, opts) unless opts[:ignore_includes]

      xml = sanitize_bare_ampersands(xml)
      xml = replace_html_entities(xml)
      doc = Nokogiri::XML(xml) { |config| config.strict }
      doc.xpath("//mj-include").each(&:remove) if opts[:ignore_includes]
      normalize_root_head_elements(doc)
      prepare_node(doc.root, keep_comments: opts[:keep_comments])
      doc.root
    rescue Nokogiri::XML::SyntaxError => e
      raise xml_parse_error(e, opts[:actual_path])
    end

    private

    def normalize_options(options)
      opts = Options::DEFAULTS.merge(Options.normalize(options))
      base = File.expand_path(opts[:file_path])
      base = File.dirname(base) if File.file?(base)
      roots = [base] + Array(opts[:include_path]).map { |root| File.expand_path(root, base) }
      opts.merge(file_path: base, allowed_roots: roots.filter_map { |root| File.realpath(root) rescue nil })
    end

    def ending_tags
      @ending_tags ||= MjmlRb.component_registry.ending_tags - STRUCTURAL_ENDING_TAGS
    end

    def ending_tag_open_re
      @ending_tag_open_re ||= /<(#{ending_tags.map { |tag| Regexp.escape(tag) }.join("|")})(\s[^<>]*?)?(?<!\/)>/mi
    end

    def outside_cdata(content)
      content.split(/(<!\[CDATA\[.*?\]\]>)/m).map do |part|
        part.start_with?("<![CDATA[") ? part : yield(part)
      end.join
    end

    def apply_preprocessors(xml, preprocessors)
      preprocessors.reduce(xml) do |current, preprocessor|
        preprocessor.respond_to?(:call) ? preprocessor.call(current).to_s : current
      end
    end

    def expand_includes(xml, options, included_in = [])
      xml = wrap_ending_tags_in_cdata(xml)
      xml = outside_cdata(xml) { |part| normalize_html_void_tags(part) }
      doc = parse_xml(sanitize_bare_ampersands(xml))
      includes = doc.xpath("//mj-include")
      return xml if includes.empty? && included_in.empty?

      annotate_include_source(doc.root, options[:actual_path]) unless included_in.empty?

      head_includes = []

      includes.each do |include_node|
        path_attr = include_node["path"]
        if path_attr.to_s.empty?
          raise ParseError.new("mj-include path is required", line: include_node.line, file: options[:actual_path], dependencies: @dependencies)
        end

        include_type = include_node["type"].to_s

        begin
          resolved_path = resolve_include_path(path_attr, options)
          @dependencies << resolved_path
          include_content = File.read(resolved_path)
        rescue IncludeDenied
          @include_errors << include_diagnostic(include_node, options, "include-denied", "mj-include denied: #{path_attr}")
          replacement = Nokogiri::XML::Node.new("mj-raw", doc)
          replacement.add_child(Nokogiri::XML::CDATA.new(doc, "<!-- mj-include denied -->"))
          include_node.replace(replacement)
          next
        rescue SystemCallError
          @include_errors << include_diagnostic(include_node, options, "include", "mj-include fails to read file : #{path_attr} at #{resolved_path}")
          include_node.remove
          next
        end

        # Circular include detection
        if included_in.include?(resolved_path)
          raise ParseError.new("Circular inclusion detected on file : #{resolved_path}", line: include_node.line, file: options[:actual_path], dependencies: @dependencies)
        end

        if include_type == "css"
          style = Nokogiri::XML::Node.new("mj-style", doc)
          style["inline"] = "inline" if include_node["css-inline"] == "inline"
          style.add_child(Nokogiri::XML::CDATA.new(doc, include_content))
          annotate_include_source(style, resolved_path)
          if include_node.parent.name == "mj-head"
            include_node.replace(style)
          else
            ensure_head(doc).add_child(style)
            include_node.remove
          end
          next
        end

        replacement = if include_type == "html"
                        %(<mj-raw><![CDATA[#{escape_cdata(include_content)}]]></mj-raw>)
                      else
                        prepared = prepare_mjml_include_document(include_content)
                        prepared = wrap_ending_tags_in_cdata(prepared)
                        expanded = expand_includes(prepared, options.merge(
                          actual_path: resolved_path,
                          file_path: File.dirname(resolved_path)
                        ), included_in + [resolved_path])
                        body_children, include_head_children = extract_mjml_include_children(expanded)
                        head_includes.push(*include_head_children)
                        body_children
                      end

        if replacement.is_a?(Array)
          replacement.each do |child|
            annotate_include_source(child, resolved_path) if child.element?
            include_node.add_previous_sibling(child)
          end
        else
          fragment = parse_xml("<include-root>#{sanitize_bare_ampersands(replacement)}</include-root>").root
          fragment.children.each do |child|
            cloned = child.dup(1)
            annotate_include_source(cloned, resolved_path) if cloned.element?
            include_node.add_previous_sibling(cloned)
          end
        end
        include_node.remove
      end

      inject_head_includes(doc, head_includes) unless head_includes.empty?

      doc.root.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML | Nokogiri::XML::Node::SaveOptions::NO_DECLARATION)
    rescue Nokogiri::XML::SyntaxError => e
      raise xml_parse_error(e, options[:actual_path])
    end

    def prepare_mjml_include_document(content)
      stripped = strip_xml_declaration(content)
      return stripped if stripped.match?(/<mjml(?=[\s>])/i)

      "<mjml><mj-body>#{stripped}</mj-body></mjml>"
    end

    def extract_mjml_include_children(xml)
      include_doc = parse_xml(sanitize_bare_ampersands(xml))
      normalize_root_head_elements(include_doc)
      mjml_root = include_doc.root
      return [[], []] unless mjml_root&.name == "mjml"

      body = mjml_root.at_xpath("mj-body")
      head = mjml_root.at_xpath("mj-head")

      [
        body ? body.children.map { |child| child.dup(1) } : [],
        head ? head.children.map { |child| child.dup(1) } : []
      ]
    end

    def inject_head_includes(doc, head_includes)
      head = ensure_head(doc)
      head_includes.each { |child| head.add_child(child) }
    end

    def ensure_head(doc)
      mjml_root = doc.root
      return unless mjml_root

      head = mjml_root.at_xpath("mj-head")
      return head if head

      head = Nokogiri::XML::Node.new("mj-head", doc)
      body = mjml_root.at_xpath("mj-body")
      if body
        body.add_previous_sibling(head)
      else
        mjml_root.add_child(head)
      end
      head
    end

    def normalize_root_head_elements(doc)
      mjml_root = doc.root
      return unless mjml_root&.name == "mjml"

      head_nodes = []
      normalized_head_children = []
      root_head_elements = []

      mjml_root.children.each do |child|
        next unless child.element?

        if child.name == "mj-head"
          head_nodes << child
          child.children.each { |head_child| normalized_head_children << head_child.dup(1) }
        elsif ROOT_LEVEL_HEAD_TAGS.include?(child.name)
          root_head_elements << child
          normalized_head_children << child.dup(1)
        end
      end

      return if root_head_elements.empty? && head_nodes.length <= 1

      head = head_nodes.first || ensure_head(doc)
      return unless head

      head.children.each(&:remove)
      normalized_head_children.each { |child| head.add_child(child) }

      root_head_elements.each(&:remove)
      head_nodes.drop(1).each(&:remove)
    end

    def strip_xml_declaration(content)
      content.sub(/\A<\?xml[^>]*\?>\s*/m, "")
    end

    def normalize_html_void_tags(content)
      # Legacy mail templates sometimes emit invalid closing </br> tags.
      # Browser-style recovery treats them as actual line breaks, so preserve that.
      content = content.gsub(VOID_TAG_CLOSING_BR_RE, "<br />")

      # Remove other closing tags for void elements (e.g. </hr>, </img>).
      # These are invalid in both HTML and XML and HTML5 recovery drops them.
      content = content.gsub(VOID_TAG_CLOSING_OTHER_RE, "")

      # Self-close opening void tags that aren't already self-closed.
      content.gsub(VOID_TAG_OPEN_RE) do |tag|
        tag.end_with?("/>") ? tag : tag.sub(/>$/, " />")
      end
    end

    def wrap_ending_tags_in_cdata(content)
      wrapped = +""
      cursor = 0

      while (match = ending_tag_open_re.match(content, cursor))
        tag = match[1]
        attrs = match[2].to_s
        wrapped << content[cursor...match.begin(0)]

        closing_range = find_matching_ending_tag(content, tag, match.end(0))
        unless closing_range
          wrapped << match[0]
          cursor = match.end(0)
          next
        end

        inner = content[match.end(0)...closing_range.begin(0)]
        if inner.include?("<![CDATA[")
          wrapped << "<#{tag}#{attrs}>#{inner}</#{tag}>"
        else
          prepared = inner
          wrapped << "<#{tag}#{attrs}><![CDATA[#{escape_cdata(prepared)}]]></#{tag}>"
        end

        cursor = closing_range.end(0)
      end

      wrapped << content[cursor..] if cursor < content.length
      wrapped
    end

    def find_matching_ending_tag(content, tag_name, cursor)
      open_tag_re = /<#{Regexp.escape(tag_name)}(\s[^<>]*?)?(?<!\/)>/mi
      close_tag_re = %r{</#{Regexp.escape(tag_name)}\s*>}i
      depth = 1

      while cursor < content.length
        cdata_index = content.index("<![CDATA[", cursor)
        open_match = open_tag_re.match(content, cursor)
        close_match = close_tag_re.match(content, cursor)

        candidates = []
        candidates << [:cdata, cdata_index, nil] if cdata_index
        candidates << [:open, open_match.begin(0), open_match] if open_match
        candidates << [:close, close_match.begin(0), close_match] if close_match
        return nil if candidates.empty?

        kind, _, match = candidates.min_by { |candidate| candidate[1] }

        case kind
        when :cdata
          cdata_end = content.index("]]>", cdata_index + 9)
          return nil unless cdata_end

          cursor = cdata_end + 3
        when :open
          depth += 1
          cursor = match.end(0)
        when :close
          depth -= 1
          return match if depth.zero?

          cursor = match.end(0)
        end
      end

      nil
    end

    def escape_cdata(content)
      content.to_s.gsub("]]>", "]]]]><![CDATA[>")
    end

    # Escape bare "&" that are not part of a valid XML entity reference
    # (e.g. &amp; &#123; &#x1F;).  This lets the XML parser handle HTML-ish
    # content such as "Terms & Conditions" which is common in email templates.
    def sanitize_bare_ampersands(content)
      outside_cdata(content) { |part| part.gsub(BARE_AMPERSAND_RE, "&amp;") }
    end

    # Replace HTML named entities (e.g. &nbsp;, &copy;) with their numeric
    # XML equivalents (e.g. &#160;, &#169;).  XML only defines five named
    # entities (amp, lt, gt, quot, apos); all other named references from
    # HTML must be converted to numeric form for the XML parser to accept them.
    # Uses Nokogiri's built-in HTML entity lookup table.
    def replace_html_entities(content)
      outside_cdata(content) do |part|
        part.gsub(/&([a-zA-Z][a-zA-Z0-9]*);/) do |match|
          name = ::Regexp.last_match(1)
          next match if XML_PREDEFINED_ENTITIES.include?(name)

          codepoint = Nokogiri::HTML::NamedCharacters[name]
          codepoint ? "&##{codepoint};" : match
        end
      end
    end

    XML_PREDEFINED_ENTITIES = %w[amp lt gt quot apos].freeze

    # Recursively marks Nokogiri elements from included files with data-mjml-file.
    # Only sets the attribute on elements that don't already have it (preserving
    # deeper include annotations from recursive expansion).
    def annotate_include_source(element, file_path)
      return unless element.element?

      if (element.name.start_with?("mj-") || element.name == "mjml") && !element["data-mjml-file"]
        element["data-mjml-file"] = file_path
        element["data-mjml-line"] = element.line.to_s
      end
      element.element_children.each { |child| annotate_include_source(child, file_path) }
    end

    class IncludeDenied < StandardError; end

    def include_diagnostic(node, options, type, message)
      {type: type, message: message, formatted_message: message,
       tag_name: "mj-include", line: node.line, file: options[:actual_path]}
    end

    def resolve_include_path(path, options)
      decoded = path.to_s
      10.times do
        next_value = URI::DEFAULT_PARSER.unescape(decoded)
        break if next_value == decoded
        decoded = next_value
      end
      if decoded.include?("\0") || decoded.start_with?("/", "\\") || decoded.match?(/\A[A-Za-z]:/)
        raise IncludeDenied
      end
      base = options[:file_path]
      candidate = File.expand_path(decoded, base)
      # Resolve every existing ancestor, including symlinks of missing targets.
      ancestor = candidate
      ancestor = File.dirname(ancestor) until File.exist?(ancestor) || File.symlink?(ancestor) || ancestor == File.dirname(ancestor)
      canonical = File.realpath(ancestor)
      allowed = options[:allowed_roots].any? { |root| canonical == root || canonical.start_with?(File.join(root, "")) }
      raise IncludeDenied unless allowed
      File.exist?(candidate) ? File.realpath(candidate) : candidate
    rescue Errno::ELOOP
      raise IncludeDenied
    end

    def prepare_node(element, keep_comments:)
      raise ParseError, "Missing XML root element" unless element

      # Mark non-mj elements for raw HTML handling
      unless element.name.start_with?("mj-") || element.name == "mjml"
        element["data-mjml-raw"] = "true"
      end

      # For ending-tag elements whose content was wrapped in CDATA,
      # mark them so raw_inner knows to extract content directly.
      if ending_tags.include?(element.name)
        element["data-mjml-ending-tag"] = "true"
        unless keep_comments
          element.children.each do |child|
            next unless child.cdata? || child.text?
            child.content = strip_source_comments(child.content)
          end
        end
        return
      end

      # Strip ignorable whitespace text nodes, unwanted comments,
      # and recurse into element children.
      element.children.to_a.each do |child|
        if child.element?
          prepare_node(child, keep_comments: keep_comments)
        elsif child.text? || child.cdata?
          text = child.content
          if text.empty? || (text.strip.empty? && ignorable_whitespace_text?(text, parent_element_name: element.name))
            child.remove
          end
        elsif child.comment?
          child.remove unless keep_comments || child.content.match?(/\A(?:\[if|<!\[endif|\s*htmlmin:ignore)/i)
        else
          child.remove
        end
      end
    end

    def strip_source_comments(content)
      content.gsub(/<(script|style|textarea)\b[^>]*>.*?<\/\1\s*>|<!--.*?-->/mi) do |part|
        if !part.start_with?("<!--") || part.match?(/\A<!--(?:\[if|<!\[endif|\s*htmlmin:ignore)/i)
          part
        else
          ""
        end
      end
    end

    def parse_xml(xml)
      Nokogiri::XML(replace_html_entities(xml)) { |config| config.strict }
    end

    def xml_parse_error(error, file)
      # Nokogiri's aggregate exception has no #line; retain the first reported
      # location while leaving its complete diagnostic message intact.
      line = error.line || error.message[/^(\d+):\d+:/, 1]&.to_i
      ParseError.new("XML parse error: #{error.message}", line: line, file: file, dependencies: @dependencies)
    end

    def ignorable_whitespace_text?(text, parent_element_name:)
      return true if parent_element_name.start_with?("mj-") || parent_element_name == "mjml"

      text.match?(/[\r\n]/)
    end
  end
end
