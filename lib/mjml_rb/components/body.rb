require_relative "base"

module MjmlRb
  module Components
    class Body < Base
      TAGS = ["mj-body"].freeze

      DEFAULTS = {
        "width" => "600px"
      }.freeze

      def tags
        TAGS
      end

      def render(tag_name:, node:, context:, attrs:, parent:)
        return render_children(node, context, parent: parent) unless tag_name == "mj-body"

        body_attrs = DEFAULTS.merge(attrs)
        background_color = body_attrs["background-color"]
        container_width = body_attrs["width"]

        context[:background_color] = background_color if background_color
        context[:container_width] = container_width

        div_attributes = {
          "aria-label" => context[:title].to_s.empty? ? nil : context[:title],
          "aria-roledescription" => "email",
          "class" => body_attrs["css-class"],
          "role" => "article",
          "lang" => context[:lang],
          "dir" => context[:dir],
          "style" => style_join("background-color" => background_color)
        }
        table_style = style_join(
          "width" => "100%",
          "max-width" => container_width,
          "margin" => "0 auto"
        )
        children = render_children(node, context, parent: "mj-body")

        %(<div#{html_attrs(div_attributes)}><table role="presentation" align="center" width="#{escape_attr(container_width)}" cellspacing="0" cellpadding="0" border="0" style="#{table_style}"><tbody>#{children}</tbody></table></div>)
      end
    end
  end
end
