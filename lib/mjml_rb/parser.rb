require "rexml/document"
require "rexml/xpath"

require_relative "ast_node"

module MjmlRb
  class Parser
    include REXML
    HTML_VOID_TAGS = %w[area base br col embed hr img input link meta param source track wbr].freeze

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
      xml = normalize_html_void_tags(xml)
      xml = expand_includes(xml, opts) unless opts[:ignore_includes]

      doc = Document.new(xml)
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

    def expand_includes(xml, options)
      xml = normalize_html_void_tags(xml)
      doc = Document.new(xml)
      includes = XPath.match(doc, "//mj-include")
      return xml if includes.empty?

      includes.reverse_each do |include_node|
        path_attr = include_node.attributes["path"]
        raise ParseError, "mj-include path is required" if path_attr.to_s.empty?

        include_type = include_node.attributes["type"].to_s
        resolved_path = resolve_include_path(path_attr, options[:actual_path], options[:file_path])
        include_content = File.read(resolved_path)

        replacement = if include_type == "html"
                        %(<mj-raw><![CDATA[#{escape_cdata(include_content)}]]></mj-raw>)
                      else
                        normalize_html_void_tags(strip_xml_declaration(include_content))
                      end

        fragment = Document.new("<include-root>#{replacement}</include-root>")
        parent = include_node.parent
        insert_before = include_node
        fragment.root.children.each do |child|
          parent.insert_before(insert_before, deep_clone(child))
        end
        parent.delete(include_node)
      end

      output = +""
      doc.write(output)
      output
    rescue Errno::ENOENT => e
      raise ParseError, "Cannot read included file: #{e.message}"
    rescue ParseException => e
      raise ParseError, "Failed to parse included content: #{e.message}"
    end

    def strip_xml_declaration(content)
      content.sub(/\A<\?xml[^>]*\?>\s*/m, "")
    end

    def normalize_html_void_tags(content)
      pattern = /<(#{HTML_VOID_TAGS.join("|")})(\s[^<>]*?)?>/i
      content.gsub(pattern) do |tag|
        tag.end_with?("/>") ? tag : tag.sub(/>$/, " />")
      end
    end

    def escape_cdata(content)
      content.to_s.gsub("]]>", "]]]]><![CDATA[>")
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
        attributes: element.attributes.to_h,
        children: children,
        line: nil
      )
    end
  end
end
