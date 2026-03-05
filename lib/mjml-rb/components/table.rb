require_relative "base"

module MjmlRb
  module Components
    class Table < Base
      TAGS = ["mj-table"].freeze

      DEFAULTS = {
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

      def tags
        TAGS
      end

      def render(tag_name:, node:, context:, attrs:, parent:)
        a = DEFAULTS.merge(attrs)

        outer_td_style = style_join(
          "background"     => a["container-background-color"],
          "font-size"      => "0px",
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

        content = raw_inner(node)
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
    end
  end
end
