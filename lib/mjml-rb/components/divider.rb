require_relative "base"

module MjmlRb
  module Components
    class Divider < Base
      TAGS = ["mj-divider"].freeze

      ALLOWED_ATTRIBUTES = {
        "border-color" => "color",
        "border-style" => "string",
        "border-width" => "unit(px)",
        "container-background-color" => "color",
        "padding" => "unit(px,%){1,4}",
        "padding-bottom" => "unit(px,%)",
        "padding-left" => "unit(px,%)",
        "padding-right" => "unit(px,%)",
        "padding-top" => "unit(px,%)",
        "width" => "unit(px,%)",
        "align" => "enum(left,center,right)"
      }.freeze

      DEFAULTS = {
        "align" => "center",
        "border-color" => "#000000",
        "border-style" => "solid",
        "border-width" => "4px",
        "padding" => "10px 25px",
        "width" => "100%"
      }.freeze

      def tags
        TAGS
      end

      def render(tag_name:, node:, context:, attrs:, parent:)
        a = DEFAULTS.merge(attrs)

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
          "class" => a["css-class"],
          "style" => outer_td_style
        }

        border_top = "#{a["border-style"]} #{a["border-width"]} #{a["border-color"]}"
        margin = compute_margin(a["align"])

        p_style = style_join(
          "border-top" => border_top,
          "font-size" => "1px",
          "margin" => margin,
          "width" => a["width"]
        )

        outlook_width = get_outlook_width(a, context)
        outlook_style = style_join(
          "border-top" => border_top,
          "font-size" => "1px",
          "margin" => margin,
          "width" => outlook_width
        )

        p_tag = %(<p style="#{p_style}"></p>)
        outlook = outlook_block(a["align"], outlook_style, outlook_width)

        %(<tr><td#{html_attrs(outer_td_attrs)}>#{p_tag}\n#{outlook}</td></tr>)
      end

      private

      def compute_margin(align)
        case align
        when "left"  then "0px"
        when "right" then "0px 0px 0px auto"
        else              "0px auto"
        end
      end

      def get_outlook_width(attrs, context)
        container_width = (context[:container_width] || "600px").to_f
        padding = attrs["padding"] || "10px 25px"
        parts = padding.split(/\s+/)
        pad_left  = shorthand_value(parts, :left).to_f
        pad_right = shorthand_value(parts, :right).to_f

        if attrs["padding-left"]
          pad_left = attrs["padding-left"].to_f
        end
        if attrs["padding-right"]
          pad_right = attrs["padding-right"].to_f
        end

        width = attrs["width"] || "100%"

        if width =~ /^(\d+(?:\.\d+)?)\s*%$/
          pct = ::Regexp.last_match(1).to_f / 100.0
          effective = container_width - pad_left - pad_right
          "#{(effective * pct).to_i}px"
        elsif width =~ /^(\d+(?:\.\d+)?)\s*px$/
          width
        else
          "#{(container_width - pad_left - pad_right).to_i}px"
        end
      end

      def outlook_block(align, style, width)
        # Strip trailing px for the HTML width attribute
        width_int = width.to_i.to_s
        <<~HTML.strip
          <!--[if mso | IE]><table align="#{escape_attr(align)}" border="0" cellpadding="0" cellspacing="0" style="#{style}" role="presentation" width="#{width_int}" ><tr><td style="height:0;line-height:0;"> &nbsp;
          </td></tr></table><![endif]-->
        HTML
      end
    end
  end
end
