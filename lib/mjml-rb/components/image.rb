require_relative "base"

module MjmlRb
  module Components
    class Image < Base
      TAGS = ["mj-image"].freeze

      DEFAULTS = {
        "alt" => "",
        "align" => "center",
        "border" => "0",
        "height" => "auto",
        "padding" => "10px 25px",
        "target" => "_blank",
        "font-size" => "13px"
      }.freeze

      HEAD_STYLE = <<~CSS.freeze
        @media only screen and (max-width:480px) {
          table.mj-full-width-mobile { width: 100% !important; }
          td.mj-full-width-mobile { width: auto !important; }
        }
      CSS

      def tags
        TAGS
      end

      def head_style
        HEAD_STYLE
      end

      def head_style_tags
        ["mj-image"]
      end

      def render(tag_name:, node:, context:, attrs:, parent:)
        a = DEFAULTS.merge(attrs)

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

        td_style = style_join(
          "width" => full_width ? nil : "#{content_width}px"
        )
        td_attrs = {
          "style" => td_style,
          "class" => fluid ? "mj-full-width-mobile" : nil
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

        height_val = a["height"]
        height_attr = if height_val && !height_val.empty?
                        height_val == "auto" ? "auto" : height_val.to_i.to_s
                      end

        img_attrs = {
          "alt" => a["alt"],
          "src" => a["src"] ? escape_attr(a["src"]) : nil,
          "srcset" => a["srcset"] ? escape_attr(a["srcset"]) : nil,
          "sizes" => a["sizes"],
          "style" => img_style,
          "title" => a["title"],
          "width" => content_width.to_s,
          "usemap" => a["usemap"],
          "height" => height_attr
        }

        img_tag = "<img#{html_attrs(img_attrs)} />"

        inner = if a["href"]
                  link_attrs = {
                    "href" => escape_attr(a["href"]),
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

      def shorthand_value(parts, side)
        case parts.length
        when 1 then parts[0]
        when 2, 3 then parts[1]
        when 4 then side == :left ? parts[3] : parts[1]
        else "0"
        end
      end
    end
  end
end
