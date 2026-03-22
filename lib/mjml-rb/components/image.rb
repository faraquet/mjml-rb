require_relative "base"

module MjmlRb
  module Components
    class Image < Base
      TAGS = ["mj-image"].freeze

      ALLOWED_ATTRIBUTES = {
        "alt" => "string",
        "href" => "string",
        "name" => "string",
        "src" => "string",
        "srcset" => "string",
        "sizes" => "string",
        "title" => "string",
        "rel" => "string",
        "align" => "enum(left,center,right)",
        "border" => "string",
        "border-bottom" => "string",
        "border-left" => "string",
        "border-right" => "string",
        "border-top" => "string",
        "border-radius" => "unit(px,%){1,4}",
        "container-background-color" => "color",
        "fluid-on-mobile" => "boolean",
        "full-width" => "enum(full-width)",
        "padding" => "unit(px,%){1,4}",
        "padding-bottom" => "unit(px,%)",
        "padding-left" => "unit(px,%)",
        "padding-right" => "unit(px,%)",
        "padding-top" => "unit(px,%)",
        "target" => "string",
        "width" => "unit(px)",
        "height" => "unit(px,auto)",
        "max-height" => "unit(px,%)",
        "font-size" => "unit(px)",
        "usemap" => "string"
      }.freeze

      DEFAULT_ATTRIBUTES = {
        "alt" => "",
        "align" => "center",
        "border" => "0",
        "height" => "auto",
        "padding" => "10px 25px",
        "target" => "_blank",
        "font-size" => "13px"
      }.freeze

      def head_style(breakpoint)
        lower_breakpoint = make_lower_breakpoint(breakpoint)

        <<~CSS
          @media only screen and (max-width:#{lower_breakpoint}) {
            table.mj-full-width-mobile { width: 100% !important; }
            td.mj-full-width-mobile { width: auto !important; }
          }
        CSS
      end

      def head_style_tags
        ["mj-image"]
      end

      def render(tag_name:, node:, context:, attrs:, parent:)
        a = DEFAULT_ATTRIBUTES.merge(attrs)

        fluid = a["fluid-on-mobile"] == "true"
        full_width = a["full-width"] == "full-width"
        content_width = get_content_width(a, context)

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

        table_style = style_join(
          "min-width" => full_width ? "100%" : nil,
          "max-width" => full_width ? "100%" : nil,
          "width" => full_width ? "#{content_width}px" : nil,
          "border-collapse" => "collapse",
          "border-spacing" => "0px"
        )
        table_attrs = {
          "border" => "0",
          "cellpadding" => "0",
          "cellspacing" => "0",
          "role" => "presentation",
          "style" => table_style,
          "class" => fluid ? "mj-full-width-mobile" : nil
        }

        td_attrs = {
          "style" => style_join("width" => full_width ? nil : "#{content_width}px"),
          "class" => fluid ? "mj-full-width-mobile" : nil,
          "width" => full_width ? nil : content_width.to_i.to_s,
          "height" => height_attribute(a["height"]),
          "align" => a["align"]
        }

        img_style = style_join(
          "border" => a["border"],
          "border-left" => a["border-left"],
          "border-right" => a["border-right"],
          "border-top" => a["border-top"],
          "border-bottom" => a["border-bottom"],
          "border-radius" => a["border-radius"],
          "display" => "block",
          "outline" => "none",
          "text-decoration" => "none",
          "height" => a["height"],
          "max-height" => a["max-height"],
          "min-width" => full_width ? "100%" : nil,
          "width" => "100%",
          "max-width" => full_width ? "100%" : nil,
          "font-size" => a["font-size"]
        )

        img_attrs = {
          "alt" => a["alt"],
          "src" => a["src"],
          "srcset" => a["srcset"],
          "sizes" => a["sizes"],
          "style" => img_style,
          "title" => a["title"],
          "width" => img_width_attribute(a, content_width),
          "usemap" => a["usemap"],
          "height" => height_attribute(a["height"])
        }

        img_tag = "<img#{html_attrs(img_attrs)} />"

        inner = if a["href"]
                  link_attrs = {
                    "href" => a["href"],
                    "target" => a["target"],
                    "rel" => a["rel"],
                    "name" => a["name"],
                    "title" => a["title"]
                  }
                  "<a#{html_attrs(link_attrs)}>#{img_tag}</a>"
                else
                  img_tag
                end

        table = %(<table#{html_attrs(table_attrs)}><tbody><tr><td#{html_attrs(td_attrs)}>#{inner}</td></tr></tbody></table>)

        %(<tr><td#{html_attrs(outer_td_attrs)}>#{table}</td></tr>)
      end

      private

      def height_attribute(height)
        return if height.nil? || height.empty?

        height == "auto" ? "auto" : height.to_i.to_s
      end

      def img_width_attribute(attrs, content_width)
        return "auto" if attrs["width"] && attrs["height"] && attrs["height"] != "auto"
        return attrs["width"].to_i.to_s if attrs["width"] && attrs["width"] =~ /^(\d+(?:\.\d+)?)\s*px$/

        content_width.to_i.to_s
      end

      def get_content_width(attrs, context)
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

        box = container_width - pad_left - pad_right

        if attrs["width"] && attrs["width"] =~ /^(\d+(?:\.\d+)?)\s*px$/
          [box, ::Regexp.last_match(1).to_f].min.to_i
        else
          box.to_i
        end
      end

      def make_lower_breakpoint(breakpoint)
        matched = breakpoint.to_s.match(/[0-9]+/)
        return breakpoint if matched.nil?

        "#{matched[0].to_i - 1}px"
      end
    end
  end
end
