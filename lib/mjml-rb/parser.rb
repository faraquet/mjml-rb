require "nokogiri"

require_relative "ast_node"
require_relative "html_entities"

module MjmlRb
  class Parser
    HTML_VOID_TAGS = %w[area base br col embed hr img input link meta param source track wbr].freeze

    # Ending-tag components whose inner HTML is preserved as raw content via CDATA
    # wrapping, matching upstream npm's endingTag behavior. mj-table is excluded
    # because its component needs structural AST access for attribute normalization.
    # mj-carousel-image is excluded because it has no meaningful inner content.
    ENDING_TAGS_FOR_CDATA = %w[
      mj-accordion-text mj-accordion-title mj-button
      mj-navbar-link mj-raw mj-text
    ].freeze

    # Pre-compiled regex patterns to avoid rebuilding on every call
    ENDING_TAG_OPEN_RE = /<(#{ENDING_TAGS_FOR_CDATA.map { |t| Regexp.escape(t) }.join("|")})(\s[^<>]*?)?(?<!\/)>/mi.freeze

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
      attr_reader :line

      def initialize(message, line: nil)
        super(message)
        @line = line
      end
    end

    # Errors collected during include expansion (missing files, etc.)
    # Read after calling #parse to retrieve non-fatal include issues.
    attr_reader :include_errors

    def parse(mjml, options = {})
      @include_errors = []
      opts = normalize_options(options)
      xml = apply_preprocessors(mjml.to_s, opts[:preprocessors])
      xml = wrap_ending_tags_in_cdata(xml)
      xml = normalize_html_void_tags(xml)
      xml = expand_includes(xml, opts) unless opts[:ignore_includes]

      xml = sanitize_bare_ampersands(xml)
      xml = replace_html_entities(xml)
      doc = Nokogiri::XML(xml) { |config| config.strict }
      normalize_root_head_elements(doc)
      element_to_ast(doc.root, keep_comments: opts[:keep_comments])
    rescue Nokogiri::XML::SyntaxError => e
      raise ParseError.new("XML parse error: #{e.message}")
    end

    private

    def normalize_options(options)
      {
        keep_comments: options[:keep_comments],
        preprocessors: Array(options[:preprocessors]),
        ignore_includes: !!options[:ignore_includes],
        file_path: options[:file_path] || ".",
        actual_path: options[:actual_path] || "."
      }
    end

    def apply_preprocessors(xml, preprocessors)
      preprocessors.reduce(xml) do |current, preprocessor|
        preprocessor.respond_to?(:call) ? preprocessor.call(current).to_s : current
      end
    end

    def expand_includes(xml, options, included_in = [])
      xml = wrap_ending_tags_in_cdata(xml)
      xml = normalize_html_void_tags(xml)
      doc = parse_xml(sanitize_bare_ampersands(xml))
      includes = doc.xpath("//mj-include")
      return xml if includes.empty?

      css_includes = []
      head_includes = []

      includes.reverse_each do |include_node|
        path_attr = include_node["path"]
        raise ParseError, "mj-include path is required" if path_attr.to_s.empty?

        include_type = include_node["type"].to_s
        parent = include_node.parent

        resolved_path = begin
          resolve_include_path(path_attr, options[:actual_path], options[:file_path])
        rescue Errno::ENOENT
          nil
        end

        include_content = resolved_path ? File.read(resolved_path) : nil

        if include_content.nil?
          display_path = resolved_path || File.expand_path(path_attr, options[:file_path].to_s)
          @include_errors << {
            message: "mj-include fails to read file : #{path_attr} at #{display_path}",
            tag_name: "mj-include",
            file: display_path
          }
          include_node.remove
          next
        end

        # Circular include detection
        if included_in.include?(resolved_path)
          raise ParseError, "Circular inclusion detected on file : #{resolved_path}"
        end

        if include_type == "css"
          # CSS includes get collected and added to mj-head later
          css_inline = include_node["css-inline"].to_s
          css_includes << { content: include_content, inline: css_inline == "inline" }
          include_node.remove
          next
        end

        replacement = if include_type == "html"
                        %(<mj-raw><![CDATA[#{escape_cdata(include_content)}]]></mj-raw>)
                      else
                        prepared = prepare_mjml_include_document(include_content)
                        prepared = wrap_ending_tags_in_cdata(normalize_html_void_tags(prepared))
                        expanded = expand_includes(prepared, options.merge(
                          actual_path: resolved_path,
                          file_path: File.dirname(resolved_path)
                        ), included_in + [resolved_path])
                        body_children, include_head_children = extract_mjml_include_children(expanded)
                        head_includes.unshift(*include_head_children)
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

      # Inject CSS includes into mj-head
      unless css_includes.empty?
        inject_css_includes(doc, css_includes)
      end

      doc.root.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML | Nokogiri::XML::Node::SaveOptions::NO_DECLARATION)
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

    def inject_css_includes(doc, css_includes)
      head = ensure_head(doc)

      # Add each CSS include as an mj-style element
      css_includes.each do |css_include|
        style_node = Nokogiri::XML::Node.new("mj-style", doc)
        style_node["inline"] = "inline" if css_include[:inline]
        style_node.add_child(Nokogiri::XML::CDATA.new(doc, css_include[:content]))
        head.add_child(style_node)
      end
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

      while (match = ENDING_TAG_OPEN_RE.match(content, cursor))
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
          # Pre-process content: normalize void tags and sanitize bare ampersands
          # before wrapping in CDATA, so the raw HTML is well-formed for output.
          prepared = sanitize_bare_ampersands(normalize_html_void_tags(inner))
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
      content.gsub(BARE_AMPERSAND_RE, "&amp;")
    end

    # Replace HTML named entities (e.g. &nbsp;, &copy;) with their numeric
    # XML equivalents (e.g. &#160;, &#169;).  XML only defines five named
    # entities (amp, lt, gt, quot, apos); all other named references from
    # HTML must be converted to numeric form for the XML parser to accept them.
    def replace_html_entities(content)
      content.gsub(/&([a-zA-Z][a-zA-Z0-9]*);/) do |match|
        name = ::Regexp.last_match(1)
        next match if XML_PREDEFINED_ENTITIES.include?(name)

        codepoint = HTML_ENTITIES[name]
        codepoint ? "&##{codepoint};" : match
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
      end
      element.element_children.each { |child| annotate_include_source(child, file_path) }
    end

    def resolve_include_path(include_path, actual_path, file_path)
      include_path = include_path.to_s
      return include_path if File.absolute_path(include_path) == include_path && File.file?(include_path)

      candidates = []
      candidates << File.expand_path(include_path, File.dirname(actual_path.to_s))
      candidates << File.expand_path(include_path, file_path.to_s)
      candidates << File.expand_path(include_path, Dir.pwd)

      existing = candidates.find { |candidate| File.file?(candidate) }
      return existing if existing

      raise Errno::ENOENT, include_path
    end

    def element_to_ast(element, keep_comments:)
      raise ParseError, "Missing XML root element" unless element

      # Extract metadata annotations (added by annotate_include_source)
      # and strip them from the public attributes hash.
      # Line numbers come from Nokogiri's native node.line.
      meta_line = element.line
      meta_file = element["data-mjml-file"]
      attrs = {}
      element.attributes.each do |name, attr|
        attrs[name] = attr.value unless name.start_with?("data-mjml-")
      end
      attrs["data-mjml-raw"] = "true" unless element.name.start_with?("mj-") || element.name == "mjml"

      # For ending-tag elements whose content was wrapped in CDATA, store
      # the raw HTML directly as content instead of parsing structurally.
      if ENDING_TAGS_FOR_CDATA.include?(element.name)
        raw_content = element.children.select { |c| c.cdata? || c.text? }.map(&:content).join
        return AstNode.new(
          tag_name: element.name,
          attributes: attrs,
          children: [],
          content: raw_content.empty? ? nil : raw_content,
          line: meta_line,
          file: meta_file
        )
      end

      children = element.children.each_with_object([]) do |child, memo|
        if child.element?
          memo << element_to_ast(child, keep_comments: keep_comments)
        elsif child.text? || child.cdata?
          text = child.content
          next if text.empty?
          next if text.strip.empty? && ignorable_whitespace_text?(text, parent_element_name: element.name)

          memo << AstNode.new(tag_name: "#text", content: text)
        elsif child.comment?
          memo << AstNode.new(tag_name: "#comment", content: child.content) if keep_comments
        end
      end

      AstNode.new(
        tag_name: element.name,
        attributes: attrs,
        children: children,
        line: meta_line,
        file: meta_file
      )
    end

    # Lenient XML parse used during include expansion and intermediate steps.
    # Errors are collected but do not raise; the final strict parse in #parse
    # will surface any real issues.
    def parse_xml(xml)
      Nokogiri::XML(replace_html_entities(xml))
    end

    def ignorable_whitespace_text?(text, parent_element_name:)
      return true if parent_element_name.start_with?("mj-") || parent_element_name == "mjml"

      text.match?(/[\r\n]/)
    end
  end
end
