require_relative "base"

module MjmlRb
  module Components
    class Button < Base
      TAGS = ["mj-button"].freeze

      ALLOWED_ATTRIBUTES = {
        "align" => "enum(left,center,right)",
        "background-color" => "color",
        "border-bottom" => "string",
        "border-left" => "string",
        "border-radius" => "string",
        "border-right" => "string",
        "border-top" => "string",
        "border" => "string",
        "color" => "color",
        "container-background-color" => "color",
        "font-family" => "string",
        "font-size" => "unit(px)",
        "font-style" => "string",
        "font-weight" => "string",
        "height" => "unit(px,%)",
        "href" => "string",
        "name" => "string",
        "title" => "string",
        "inner-padding" => "unit(px,%){1,4}",
        "letter-spacing" => "unit(px,em)",
        "line-height" => "unit(px,%,)",
        "padding-bottom" => "unit(px,%)",
        "padding-left" => "unit(px,%)",
        "padding-right" => "unit(px,%)",
        "padding-top" => "unit(px,%)",
        "padding" => "unit(px,%){1,4}",
        "rel" => "string",
        "target" => "string",
        "text-decoration" => "string",
        "text-transform" => "string",
        "vertical-align" => "enum(top,bottom,middle)",
        "text-align" => "enum(left,right,center)",
        "width" => "unit(px,%)"
      }.freeze

      DEFAULTS = {
        "align" => "center",
        "background-color" => "#414141",
        "border" => "none",
        "border-radius" => "3px",
        "color" => "#ffffff",
        "font-family" => "Ubuntu, Helvetica, Arial, sans-serif",
        "font-size" => "13px",
        "font-weight" => "normal",
        "inner-padding" => "10px 25px",
        "line-height" => "120%",
        "padding" => "10px 25px",
        "target" => "_blank",
        "text-decoration" => "none",
        "text-transform" => "none",
        "vertical-align" => "middle"
      }.freeze

      def tags
        TAGS
      end

      def render(tag_name:, node:, context:, attrs:, parent:)
        a = DEFAULTS.merge(attrs)

        bg_color = a["background-color"]
        inner_padding = a["inner-padding"]
        vertical_align = a["vertical-align"]
        href = a["href"]
        tag = href ? "a" : "p"

        outer_td_style = style_join(
          "background" => a["container-background-color"],
          "font-size" => "0px",
          "padding" => a["padding"],
          "padding-top" => a["padding-top"],
          "padding-right" => a["padding-right"],
          "padding-bottom" => a["padding-bottom"],
          "padding-left" => a["padding-left"],
          "word-break" => "break-word"
        )
        outer_td_attrs = {
          "align" => a["align"],
          "vertical-align" => vertical_align,
          "class" => a["css-class"],
          "style" => outer_td_style
        }

        table_style = style_join(
          "border-collapse" => "separate",
          "width" => a["width"],
          "line-height" => "100%"
        )

        td_style = style_join(
          "border" => a["border"],
          "border-bottom" => a["border-bottom"],
          "border-left" => a["border-left"],
          "border-radius" => a["border-radius"],
          "border-right" => a["border-right"],
          "border-top" => a["border-top"],
          "cursor" => "auto",
          "font-style" => a["font-style"],
          "height" => a["height"],
          "mso-padding-alt" => inner_padding,
          "text-align" => a["text-align"],
          "background" => bg_color == "none" ? nil : bg_color
        )
        td_attrs = {
          "align" => "center",
          "bgcolor" => bg_color == "none" ? nil : bg_color,
          "role" => "presentation",
          "style" => td_style,
          "valign" => vertical_align
        }

        link_style = style_join(
          "display" => "inline-block",
          "width" => calculate_a_width(a),
          "background" => bg_color == "none" ? nil : bg_color,
          "color" => a["color"],
          "font-family" => a["font-family"],
          "font-size" => a["font-size"],
          "font-style" => a["font-style"],
          "font-weight" => a["font-weight"],
          "line-height" => a["line-height"],
          "letter-spacing" => a["letter-spacing"],
          "margin" => "0",
          "text-decoration" => a["text-decoration"],
          "text-transform" => a["text-transform"],
          "padding" => inner_padding,
          "mso-padding-alt" => "0px",
          "border-radius" => a["border-radius"]
        )
        link_attrs = { "style" => link_style }
        if tag == "a"
          link_attrs["href"] = href
          link_attrs["name"] = a["name"]
          link_attrs["rel"] = a["rel"]
          link_attrs["title"] = a["title"]
          link_attrs["target"] = a["target"]
        else
          link_attrs["name"] = a["name"]
          link_attrs["title"] = a["title"]
        end

        content = raw_inner(node)
        inner_tag = %(<#{tag}#{html_attrs(link_attrs)}>#{content}</#{tag}>)
        table = %(<table border="0" cellpadding="0" cellspacing="0" role="presentation" style="#{table_style}"><tbody><tr><td#{html_attrs(td_attrs)}>#{inner_tag}</td></tr></tbody></table>)

        %(<tr><td#{html_attrs(outer_td_attrs)}>#{table}</td></tr>)
      end

      private

      def calculate_a_width(attrs)
        width = attrs["width"]
        return nil unless width
        return nil unless width =~ /^(\d+(?:\.\d+)?)\s*px$/

        parsed_width = ::Regexp.last_match(1).to_f
        inner_padding = attrs["inner-padding"] || "10px 25px"
        parts = inner_padding.split(/\s+/)
        left_pad  = shorthand_value(parts, :left).to_f
        right_pad = shorthand_value(parts, :right).to_f
        border_left  = parse_border_width(attrs["border-left"]  || attrs["border"] || "none")
        border_right = parse_border_width(attrs["border-right"] || attrs["border"] || "none")

        result = parsed_width - left_pad - right_pad - border_left - border_right
        "#{result.to_i}px"
      end

      def shorthand_value(parts, side)
        case parts.length
        when 1 then parts[0]
        when 2, 3 then parts[1]
        when 4 then side == :left ? parts[3] : parts[1]
        else "0"
        end
      end

      def parse_border_width(border_str)
        return 0 if border_str.nil? || border_str.strip == "none"

        m = border_str.match(/(\d+(?:\.\d+)?)\s*px/)
        m ? m[1].to_f : 0
      end
    end
  end
end
