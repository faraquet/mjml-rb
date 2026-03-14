require_relative "base"

module MjmlRb
  module Components
    class Hero < Base
      TAGS = ["mj-hero"].freeze

      ALLOWED_ATTRIBUTES = {
        "mode" => "enum(fixed-height,fluid-height)",
        "height" => "unit(px,%)",
        "background-url" => "string",
        "background-width" => "unit(px,%)",
        "background-height" => "unit(px,%)",
        "background-position" => "string",
        "border-radius" => "string",
        "container-background-color" => "color",
        "inner-background-color" => "color",
        "inner-padding" => "unit(px,%){1,4}",
        "inner-padding-top" => "unit(px,%)",
        "inner-padding-left" => "unit(px,%)",
        "inner-padding-right" => "unit(px,%)",
        "inner-padding-bottom" => "unit(px,%)",
        "padding" => "unit(px,%){1,4}",
        "padding-bottom" => "unit(px,%)",
        "padding-left" => "unit(px,%)",
        "padding-right" => "unit(px,%)",
        "padding-top" => "unit(px,%)",
        "background-color" => "color",
        "vertical-align" => "enum(top,bottom,middle)"
      }.freeze

      DEFAULT_ATTRIBUTES = {
        "mode" => "fixed-height",
        "height" => "0px",
        "background-url" => nil,
        "background-position" => "center center",
        "padding" => "0px",
        "padding-bottom" => nil,
        "padding-left" => nil,
        "padding-right" => nil,
        "padding-top" => nil,
        "background-color" => "#ffffff",
        "vertical-align" => "top"
      }.freeze

      def tags
        TAGS
      end

      def render(tag_name:, node:, context:, attrs:, parent:)
        a = DEFAULT_ATTRIBUTES.merge(attrs)
        container_width = normalize_container_width(context[:container_width] || "600px")
        content_width = hero_container_width(a, container_width)

        content = with_container_width(context, content_width) do
          render_children(node, context, parent: "mj-hero")
        end

        div_attrs = {
          "class" => a["css-class"],
          "style" => style_join(
            "margin" => "0 auto",
            "max-width" => container_width
          )
        }

        table_attrs = {
          "border" => "0",
          "cellpadding" => "0",
          "cellspacing" => "0",
          "role" => "presentation",
          "style" => "width:100%;",
          "width" => "100%"
        }

        wrapper = %(<div#{html_attrs(div_attrs)}><table#{html_attrs(table_attrs)}><tbody><tr style="vertical-align:top;">#{render_mode(a, content, container_width)}</tr></tbody></table></div>)

        "#{outlook_before(a, container_width)}#{wrapper}#{outlook_after}"
      end

      private

      def render_mode(attrs, content, container_width)
        common_attrs = {
          "background" => attrs["background-url"],
          "style" => style_join(
            "background" => background_style(attrs),
            "background-position" => attrs["background-position"],
            "background-repeat" => "no-repeat",
            "border-radius" => attrs["border-radius"],
            "padding" => attrs["padding"],
            "padding-top" => attrs["padding-top"],
            "padding-left" => attrs["padding-left"],
            "padding-right" => attrs["padding-right"],
            "padding-bottom" => attrs["padding-bottom"],
            "vertical-align" => attrs["vertical-align"]
          )
        }

        if attrs["mode"] == "fluid-height"
          ratio = background_ratio(attrs, container_width)
          fluid_td_attrs = {
            "style" => style_join(
              "width" => "0.01%",
              "padding-bottom" => "#{ratio}%",
              "mso-padding-bottom-alt" => "0"
            )
          }

          [
            %(<td#{html_attrs(fluid_td_attrs)}></td>),
            %(<td#{html_attrs(common_attrs)}>#{render_content(attrs, content, container_width)}</td>),
            %(<td#{html_attrs(fluid_td_attrs)}></td>)
          ].join
        else
          height = [parse_unit_value(attrs["height"]) - padding_side(attrs, "top") - padding_side(attrs, "bottom"), 0].max
          fixed_attrs = common_attrs.merge(
            "height" => height.to_i.to_s,
            "style" => style_join(
              "background" => background_style(attrs),
              "background-position" => attrs["background-position"],
              "background-repeat" => "no-repeat",
              "border-radius" => attrs["border-radius"],
              "padding" => attrs["padding"],
              "padding-top" => attrs["padding-top"],
              "padding-left" => attrs["padding-left"],
              "padding-right" => attrs["padding-right"],
              "padding-bottom" => attrs["padding-bottom"],
              "vertical-align" => attrs["vertical-align"],
              "height" => "#{height.to_i}px"
            )
          )
          %(<td#{html_attrs(fixed_attrs)}>#{render_content(attrs, content, container_width)}</td>)
        end
      end

      def render_content(attrs, content, container_width)
        outlook_attrs = {
          "align" => "center",
          "border" => "0",
          "cellpadding" => "0",
          "cellspacing" => "0",
          "role" => "presentation",
          "width" => container_width.delete_suffix("px"),
          "style" => "width:#{container_width};"
        }
        outlook_td_style = style_join(
          "background-color" => attrs["inner-background-color"],
          "padding" => attrs["inner-padding"],
          "padding-top" => attrs["inner-padding-top"],
          "padding-left" => attrs["inner-padding-left"],
          "padding-right" => attrs["inner-padding-right"],
          "padding-bottom" => attrs["inner-padding-bottom"]
        )
        inner_div_attrs = {
          "class" => "mj-hero-content",
          "style" => style_join(
            "background-color" => attrs["inner-background-color"],
            "margin" => "0px auto"
          )
        }
        inner_table_attrs = {
          "border" => "0",
          "cellpadding" => "0",
          "cellspacing" => "0",
          "role" => "presentation",
          "style" => "width:100%;margin:0px;",
          "width" => "100%"
        }

        [
          %(<!--[if mso | IE]><table#{html_attrs(outlook_attrs)}><tr><td style="#{outlook_td_style}"><![endif]-->),
          %(<div#{html_attrs(inner_div_attrs)}><table#{html_attrs(inner_table_attrs)}><tbody>#{content}</tbody></table></div>),
          %(<!--[if mso | IE]></td></tr></table><![endif]-->)
        ].join
      end

      def outlook_before(attrs, container_width)
        table_attrs = {
          "align" => "center",
          "border" => "0",
          "cellpadding" => "0",
          "cellspacing" => "0",
          "role" => "presentation",
          "style" => "width:#{container_width};",
          "width" => container_width.delete_suffix("px")
        }
        image_attrs = {
          "style" => style_join(
            "border" => "0",
            "height" => attrs["background-height"],
            "mso-position-horizontal" => "center",
            "position" => "absolute",
            "top" => "0",
            "width" => attrs["background-width"] || container_width,
            "z-index" => "-3"
          ),
          "src" => attrs["background-url"],
          "xmlns:v" => "urn:schemas-microsoft-com:vml"
        }

        opening = %(<!--[if mso | IE]><table#{html_attrs(table_attrs)}><tr><td style="line-height:0;font-size:0;mso-line-height-rule:exactly;">)
        return "#{opening}<![endif]-->" if attrs["background-url"].nil? || attrs["background-url"].empty?

        "#{opening}<v:image#{html_attrs(image_attrs)} /><![endif]-->"
      end

      def outlook_after
        %(<!--[if mso | IE]></td></tr></table><![endif]-->)
      end

      def background_style(attrs)
        parts = [attrs["background-color"]]
        if attrs["background-url"] && !attrs["background-url"].empty?
          parts << %(url('#{attrs["background-url"]}'))
          parts << "no-repeat"
          parts << "#{attrs["background-position"]} / cover"
        end
        parts.compact.join(" ")
      end

      def background_ratio(attrs, container_width)
        background_height = parse_unit_value(attrs["background-height"])
        background_width = parse_unit_value(attrs["background-width"] || container_width)
        return 0 if background_width.zero?

        ((background_height / background_width) * 100).round
      end

      def with_container_width(context, width)
        previous = context[:container_width]
        context[:container_width] = width
        yield
      ensure
        context[:container_width] = previous
      end

      def hero_container_width(attrs, container_width)
        width = parse_unit_value(container_width)
        content_width = width - padding_side(attrs, "left") - padding_side(attrs, "right")
        "#{[content_width, 0].max}px"
      end

      def normalize_container_width(value)
        "#{parse_unit_value(value)}px"
      end

      def padding_side(attrs, side)
        specific = attrs["padding-#{side}"]
        return parse_unit_value(specific) unless blank?(specific)

        padding_shorthand_value(attrs["padding"], side)
      end

      def padding_shorthand_value(value, side)
        return 0 if blank?(value)

        parts = value.to_s.strip.split(/\s+/)
        case parts.length
        when 1
          parse_unit_value(parts[0])
        when 2
          %w[left right].include?(side) ? parse_unit_value(parts[1]) : parse_unit_value(parts[0])
        when 3
          %w[left right].include?(side) ? parse_unit_value(parts[1]) : parse_unit_value(side == "top" ? parts[0] : parts[2])
        when 4
          parse_unit_value(parts[side == "left" ? 3 : 1])
        else
          0
        end
      end

      def parse_unit_value(value)
        return 0 if blank?(value)

        match = value.to_s.match(/-?\d+(?:\.\d+)?/)
        match ? match[0].to_f : 0
      end

      def blank?(value)
        value.nil? || value.to_s.empty?
      end
    end
  end
end
