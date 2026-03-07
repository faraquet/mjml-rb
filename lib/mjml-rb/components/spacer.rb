require_relative "base"

module MjmlRb
  module Components
    class Spacer < Base
      TAGS = ["mj-spacer"].freeze

      ALLOWED_ATTRIBUTES = {
        "border" => "string",
        "border-bottom" => "string",
        "border-left" => "string",
        "border-right" => "string",
        "border-top" => "string",
        "container-background-color" => "color",
        "padding-bottom" => "unit(px,%)",
        "padding-left" => "unit(px,%)",
        "padding-right" => "unit(px,%)",
        "padding-top" => "unit(px,%)",
        "padding" => "unit(px,%){1,4}",
        "height" => "unit(px,%)"
      }.freeze

      DEFAULT_ATTRIBUTES = {
        "height" => "20px"
      }.freeze

      def tags
        TAGS
      end

      def render(tag_name:, node:, context:, attrs:, parent:)
        a = self.class.default_attributes.merge(attrs)
        height = a["height"]
        outer_td_attrs = {
          "class" => a["css-class"],
          "style" => style_join(
            "background" => a["container-background-color"],
            "border" => a["border"],
            "border-bottom" => a["border-bottom"],
            "border-left" => a["border-left"],
            "border-right" => a["border-right"],
            "border-top" => a["border-top"],
            "padding" => a["padding"],
            "padding-top" => a["padding-top"],
            "padding-right" => a["padding-right"],
            "padding-bottom" => a["padding-bottom"],
            "padding-left" => a["padding-left"],
            "word-break" => "break-word"
          )
        }
        div_attrs = {
          "style" => style_join(
            "height" => height,
            "line-height" => height,
            "font-size" => "0"
          )
        }

        %(<tr><td#{html_attrs(outer_td_attrs)}><div#{html_attrs(div_attrs)}>&#8202;</div></td></tr>)
      end
    end
  end
end
