require "rexml/document"
require "rexml/xpath"

require_relative "ast_node"

module MjmlRb
  class Parser
    include REXML
    HTML_VOID_TAGS = %w[area base br col embed hr img input link meta param source track wbr].freeze

    # Ending-tag components whose inner HTML is preserved as raw content via CDATA
    # wrapping, matching upstream npm's endingTag behavior. mj-table is excluded
    # because its component needs structural AST access for attribute normalization.
    # mj-carousel-image is excluded because it has no meaningful inner content.
    ENDING_TAGS_FOR_CDATA = %w[
      mj-accordion-text mj-accordion-title mj-button
      mj-navbar-link mj-raw mj-text
    ].freeze

    class ParseError < StandardError
      attr_reader :line

      def initialize(message, line: nil)
        super(message)
        @line = line
      end
    end

    def parse(mjml, options = {})
      opts = normalize_options(options)
      xml = apply_preprocessors(mjml.to_s, opts[:preprocessors])
      xml = wrap_ending_tags_in_cdata(xml)
      xml = normalize_html_void_tags(xml)
      xml = expand_includes(xml, opts) unless opts[:ignore_includes]

      doc = Document.new(sanitize_bare_ampersands(xml))
      element_to_ast(doc.root, keep_comments: opts[:keep_comments])
    rescue ParseException => e
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
      doc = Document.new(sanitize_bare_ampersands(xml))
      includes = XPath.match(doc, "//mj-include")
      return xml if includes.empty?

      css_includes = []

      includes.reverse_each do |include_node|
        path_attr = include_node.attributes["path"]
        raise ParseError, "mj-include path is required" if path_attr.to_s.empty?

        include_type = include_node.attributes["type"].to_s
        parent = include_node.parent

        resolved_path = begin
          resolve_include_path(path_attr, options[:actual_path], options[:file_path])
        rescue Errno::ENOENT
          nil
        end

        include_content = resolved_path ? File.read(resolved_path) : nil

        if include_content.nil?
          # Collect error as an mj-raw comment node instead of raising
          display_path = resolved_path || File.expand_path(path_attr, options[:file_path].to_s)
          error_comment = "<!-- mj-include fails to read file : #{path_attr} at #{display_path} -->"
          error_node = Element.new("mj-raw")
          error_node.add(CData.new(error_comment))
          parent.insert_before(include_node, error_node)
          parent.delete(include_node)
          next
        end

        # Circular include detection
        if included_in.include?(resolved_path)
          raise ParseError, "Circular inclusion detected on file : #{resolved_path}"
        end

        if include_type == "css"
          # CSS includes get collected and added to mj-head later
          css_inline = include_node.attributes["css-inline"].to_s
          css_includes << { content: include_content, inline: css_inline == "inline" }
          parent.delete(include_node)
          next
        end

        replacement = if include_type == "html"
                        %(<mj-raw><![CDATA[#{escape_cdata(include_content)}]]></mj-raw>)
                      else
                        prepared = wrap_ending_tags_in_cdata(normalize_html_void_tags(strip_xml_declaration(include_content)))
                        # Recursively expand includes in the included content
                        expand_includes(prepared, options.merge(
                          actual_path: resolved_path,
                          file_path: File.dirname(resolved_path)
                        ), included_in + [resolved_path])
                      end

        fragment = Document.new(sanitize_bare_ampersands("<include-root>#{replacement}</include-root>"))
        insert_before = include_node
        fragment.root.children.each do |child|
          parent.insert_before(insert_before, deep_clone(child))
        end
        parent.delete(include_node)
      end

      # Inject CSS includes into mj-head
      unless css_includes.empty?
        inject_css_includes(doc, css_includes)
      end

      output = +""
      doc.write(output)
      output
    rescue ParseException => e
      raise ParseError, "Failed to parse included content: #{e.message}"
    end

    def inject_css_includes(doc, css_includes)
      mjml_root = doc.root
      return unless mjml_root

      # Find or create mj-head
      head = XPath.first(mjml_root, "mj-head")
      unless head
        head = Element.new("mj-head")
        # Insert mj-head before mj-body if possible
        body = XPath.first(mjml_root, "mj-body")
        if body
          mjml_root.insert_before(body, head)
        else
          mjml_root.add(head)
        end
      end

      # Add each CSS include as an mj-style element
      css_includes.each do |css_include|
        style_node = Element.new("mj-style")
        style_node.add_attribute("inline", "inline") if css_include[:inline]
        style_node.add(CData.new(css_include[:content]))
        head.add(style_node)
      end
    end

    def strip_xml_declaration(content)
      content.sub(/\A<\?xml[^>]*\?>\s*/m, "")
    end

    def normalize_html_void_tags(content)
      # Legacy mail templates sometimes emit invalid closing </br> tags.
      # Browser-style recovery treats them as actual line breaks, so preserve that.
      content = content.gsub(%r{</br\s*>}i, "<br />")

      # Remove other closing tags for void elements (e.g. </hr>, </img>).
      # These are invalid in both HTML and XML and HTML5 recovery drops them.
      content = content.gsub(/<\/(#{(HTML_VOID_TAGS - ["br"]).join("|")})\s*>/i, "")

      # Self-close opening void tags that aren't already self-closed.
      pattern = /<(#{HTML_VOID_TAGS.join("|")})(\s[^<>]*?)?>/i
      content.gsub(pattern) do |tag|
        tag.end_with?("/>") ? tag : tag.sub(/>$/, " />")
      end
    end

    def wrap_ending_tags_in_cdata(content)
      tag_pattern = ENDING_TAGS_FOR_CDATA.map { |t| Regexp.escape(t) }.join("|")
      # Negative lookbehind (?<!\/) ensures self-closing tags like <mj-text ... /> are skipped
      content.gsub(/<(#{tag_pattern})(\s[^<>]*?)?(?<!\/)>(.*?)<\/\1>/mi) do
        tag = Regexp.last_match(1)
        attrs = Regexp.last_match(2).to_s
        inner = Regexp.last_match(3).to_s
        if inner.include?("<![CDATA[")
          "<#{tag}#{attrs}>#{inner}</#{tag}>"
        else
          # Pre-process content: normalize void tags and sanitize bare ampersands
          # before wrapping in CDATA, so the raw HTML is well-formed for output.
          prepared = sanitize_bare_ampersands(normalize_html_void_tags(inner))
          "<#{tag}#{attrs}><![CDATA[#{escape_cdata(prepared)}]]></#{tag}>"
        end
      end
    end

    def escape_cdata(content)
      content.to_s.gsub("]]>", "]]]]><![CDATA[>")
    end

    # Escape bare "&" that are not part of a valid XML entity reference
    # (e.g. &amp; &#123; &#x1F;).  This lets REXML parse HTML-ish content
    # such as "Terms & Conditions" which is common in email templates.
    def sanitize_bare_ampersands(content)
      content.gsub(/&(?!(?:#[0-9]+|#x[0-9a-fA-F]+|[a-zA-Z][a-zA-Z0-9]*);)/, "&amp;")
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

    def deep_clone(node)
      case node
      when Element
        clone = Element.new(node.name)
        node.attributes.each_attribute { |attr| clone.add_attribute(attr.expanded_name, attr.value) }
        node.children.each { |child| clone.add(deep_clone(child)) }
        clone
      when Text
        Text.new(node.value)
      when Comment
        Comment.new(node.string)
      else
        node
      end
    end

    def element_to_ast(element, keep_comments:)
      raise ParseError, "Missing XML root element" unless element

      # For ending-tag elements whose content was wrapped in CDATA, store
      # the raw HTML directly as content instead of parsing structurally.
      if ENDING_TAGS_FOR_CDATA.include?(element.name)
        raw_content = element.children.select { |c| c.is_a?(Text) }.map(&:value).join
        return AstNode.new(
          tag_name: element.name,
          attributes: element.attributes.each_with_object({}) { |(name, val), h| h[name] = val },
          children: [],
          content: raw_content.empty? ? nil : raw_content,
          line: nil
        )
      end

      children = element.children.each_with_object([]) do |child, memo|
        case child
        when Element
          memo << element_to_ast(child, keep_comments: keep_comments)
        when Text
          text = child.value
          memo << AstNode.new(tag_name: "#text", content: text) unless text.strip.empty?
        when Comment
          memo << AstNode.new(tag_name: "#comment", content: child.string) if keep_comments
        end
      end

      AstNode.new(
        tag_name: element.name,
        attributes: element.attributes.each_with_object({}) { |(name, val), h| h[name] = val },
        children: children,
        line: nil
      )
    end
  end
end
