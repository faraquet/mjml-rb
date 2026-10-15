require_relative "base"

module MjmlRb
  module Components
    class Body < Base
      TAGS = ["mj-body"].freeze

      ALLOWED_ATTRIBUTES = {
        "width" => "unit(px)",
        "id" => "string",
        "background-color" => "color"
      }.freeze

      DEFAULT_ATTRIBUTES = {
        "width" => "600px"
      }.freeze

      def render(tag_name:, node:, context:, attrs:, parent:)
        return render_children(node, context, parent: parent) unless tag_name == "mj-body"

        body_attrs = self.class.default_attributes.merge(attrs)
        background_color = body_attrs["background-color"]
        container_width = body_attrs["width"]

        context[:background_color] = background_color
        context[:container_width] = container_width

        div_attributes = {
          "aria-label" => context[:title].to_s.empty? ? nil : context[:title],
          "aria-roledescription" => "email",
          "role" => "article",
          "lang" => context[:lang],
          "dir" => context[:dir],
          "style" => style_join("word-spacing" => "normal", "background-color" => background_color)
        }
        children = render_children(node, context, parent: "mj-body")

        body_attributes = {"id" => body_attrs["id"], "class" => body_attrs["css-class"], "style" => div_attributes["style"]}
        preview = context[:preview].to_s
        preview_block = preview.empty? ? "" : %(<div style="display:none;font-size:1px;color:#ffffff;line-height:1px;max-height:0px;max-width:0px;opacity:0;overflow:hidden;">#{escape_html(preview)}</div>)
        %(<body#{html_attrs(body_attributes)}>\n    #{preview_block}\n    <div#{html_attrs(div_attributes)}>#{children}</div>\n  </body>)
      end
    end
  end
end
