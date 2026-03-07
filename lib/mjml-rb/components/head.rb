require_relative "base"

module MjmlRb
  module Components
    class Head < Base
      TAGS = %w[mj-head mj-title mj-preview mj-style mj-font].freeze

      ALLOWED_ATTRIBUTES = {
        "mj-style" => {
          "inline" => "string"
        },
        "mj-font" => {
          "name" => "string",
          "href" => "string"
        }
      }.freeze

      class << self
        def allowed_attributes_for(tag_name)
          ALLOWED_ATTRIBUTES[tag_name] || {}
        end

        def allowed_attributes
          {}
        end
      end

      def tags
        TAGS
      end

      def render(tag_name:, node:, context:, attrs:, parent:)
        ""
      end

      def handle_head(node, context)
        case node.tag_name
        when "mj-head"
          node.element_children.each do |child|
            component = renderer.send(:component_for, child.tag_name)
            component.handle_head(child, context) if component&.respond_to?(:handle_head)
          end
        when "mj-title"
          context[:title] = raw_inner(node).strip
        when "mj-preview"
          context[:preview] = raw_inner(node).strip
        when "mj-style"
          css = raw_inner(node)
          context[:head_styles] << css
          context[:inline_styles] << css if node.attributes["inline"] == "inline"
        when "mj-font"
          name = node.attributes["name"]
          href = node.attributes["href"]
          context[:fonts][name] = href if name && href
        end
      end
    end
  end
end
