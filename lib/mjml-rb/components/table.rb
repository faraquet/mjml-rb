require_relative "base"

module MjmlRb
  module Components
    class Table < Base
      TAGS = ["mj-table"].freeze

      ALLOWED_ATTRIBUTES = {
        "align" => "enum(left,right,center)",
        "border" => "string",
        "cellpadding" => "integer",
        "cellspacing" => "integer",
        "color" => "color",
        "container-background-color" => "color",
        "font-family" => "string",
        "font-size" => "unit(px)",
        "font-weight" => "string",
        "line-height" => "unit(px,%,)",
        "padding" => "unit(px,%){1,4}",
        "padding-top" => "unit(px,%)",
        "padding-right" => "unit(px,%)",
        "padding-bottom" => "unit(px,%)",
        "padding-left" => "unit(px,%)",
        "role" => "enum(none,presentation)",
        "table-layout" => "enum(auto,fixed,initial,inherit)",
        "vertical-align" => "enum(top,bottom,middle)",
        "width" => "unit(px,%,auto)"
      }.freeze

      DEFAULT_ATTRIBUTES = {
        "align"        => "left",
        "border"       => "none",
        "cellpadding"  => "0",
        "cellspacing"  => "0",
        "color"        => "#000000",
        "font-family"  => "Ubuntu, Helvetica, Arial, sans-serif",
        "font-size"    => "13px",
        "line-height"  => "22px",
        "padding"      => "10px 25px",
        "table-layout" => "auto",
        "width"        => "100%"
      }.freeze

      def render(tag_name:, node:, context:, attrs:, parent:)
        a = DEFAULT_ATTRIBUTES.merge(attrs)

        outer_td_style = style_join(
          "background"     => a["container-background-color"],
          "font-size"      => "0px",
          "font-family"    => "inherit",
          "padding"        => a["padding"],
          "padding-top"    => a["padding-top"],
          "padding-right"  => a["padding-right"],
          "padding-bottom" => a["padding-bottom"],
          "padding-left"   => a["padding-left"],
          "word-break"     => "break-word"
        )
        outer_td_attrs = {
          "align"          => a["align"],
          "vertical-align" => a["vertical-align"],
          "class"          => a["css-class"],
          "style"          => outer_td_style
        }

        cellspacing_has_value = has_cellspacing?(a["cellspacing"])
        table_style = style_join(
          "color"           => a["color"],
          "font-family"     => a["font-family"],
          "font-size"       => a["font-size"],
          "font-weight"     => a["font-weight"],
          "line-height"     => a["line-height"],
          "table-layout"    => a["table-layout"],
          "width"           => a["width"],
          "border"          => a["border"],
          "border-collapse" => (cellspacing_has_value ? "separate" : nil)
        )

        # Attribute order matches official mjml output: cellpadding, cellspacing, role, width, border, style
        table_attrs = {
          "cellpadding" => a["cellpadding"],
          "cellspacing" => a["cellspacing"],
          "role"        => a["role"],
          "width"       => get_width(a["width"]),
          "border"      => "0",
          "style"       => table_style
        }

        content = serialize_table_children(node)
        table_html = %(<table#{html_attrs(table_attrs)}>#{content}</table>)

        %(<tr><td#{html_attrs(outer_td_attrs)}>#{table_html}</td></tr>)
      end

      private

      def get_width(width)
        return width if width == "auto"

        if width =~ /^(\d+(?:\.\d+)?)\s*%$/
          width # keep as "100%"
        elsif width =~ /^(\d+(?:\.\d+)?)\s*px$/
          ::Regexp.last_match(1) # return just the number e.g. "300"
        else
          width
        end
      end

      def has_cellspacing?(cellspacing)
        return false if cellspacing.nil? || cellspacing.to_s.strip.empty?

        num = cellspacing.to_s.gsub(/[^\d.]/, "").to_f
        num > 0
      end

      def serialize_table_children(node)
        node.children.map { |child| serialize_table_node(child) }.join
      end

      def serialize_table_node(node)
        return node.content.to_s if node.text?
        return "" if node.comment?

        attrs = normalize_table_node_attributes(node)
        attr_html = attrs.map { |key, value| %( #{key}="#{escape_attr(value)}") }.join

        return "<#{node.tag_name}#{attr_html} />" if node.children.empty?

        inner = node.children.map { |child| serialize_table_node(child) }.join
        "<#{node.tag_name}#{attr_html}>#{inner}</#{node.tag_name}>"
      end

      def normalize_table_node_attributes(node)
        attrs = node.attributes.dup
        style_map = parse_style_map(attrs["style"])

        if %w[table td th a].include?(node.tag_name)
          style_map["font-family"] ||= "inherit"
        end

        if node.tag_name == "table"
          unless attrs.key?("width") || style_map.key?("width")
            attrs["width"] = "100%"
            style_map["width"] = "100%"
          end
        end

        if %w[td th].include?(node.tag_name)
          attrs["width"] ||= style_to_html_width(style_map["width"])
          attrs["align"] ||= style_map["text-align"] if style_map["text-align"]
          attrs["valign"] ||= style_map["vertical-align"] if style_map["vertical-align"]
        end

        attrs["style"] = serialize_style_map(style_map) unless style_map.empty?
        attrs.delete("style") if style_map.empty?
        attrs.compact
      end

      def parse_style_map(style)
        return {} if style.nil? || style.strip.empty?

        style.split(";").each_with_object({}) do |declaration, memo|
          key, value = declaration.split(":", 2).map { |part| part&.strip }
          next if key.nil? || key.empty? || value.nil? || value.empty?

          memo[key] = value
        end
      end

      def serialize_style_map(style_map)
        style_map.map { |key, value| "#{key}: #{value}" }.join("; ")
      end

      def style_to_html_width(value)
        return if value.nil?

        match = value.match(/\A(\d+(?:\.\d+)?)px\z/)
        match ? match[1] : value
      end
    end
  end
end
