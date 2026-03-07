require_relative "base"

module MjmlRb
  module Components
    class HtmlAttributes < Base
      TAGS = %w[mj-html-attributes mj-selector mj-html-attribute].freeze

      ALLOWED_ATTRIBUTES = {
        "mj-selector" => {
          "path" => "string"
        },
        "mj-html-attribute" => {
          "name" => "string"
        }
      }.freeze

      class << self
        def allowed_attributes_for(tag_name)
          ALLOWED_ATTRIBUTES[tag_name] || {}
        end
      end

      def self.allowed_attributes
        {}
      end

      def render(tag_name:, node:, context:, attrs:, parent:)
        render_children(node, context, parent: parent)
      end

      def handle_head(node, context)
        node.element_children.each do |selector|
          next unless selector.tag_name == "mj-selector"

          path = selector.attributes["path"].to_s.strip
          next if path.empty?

          custom_attrs = selector.element_children.each_with_object({}) do |child, memo|
            next unless child.tag_name == "mj-html-attribute"

            name = child.attributes["name"].to_s.strip
            next if name.empty?

            memo[name] = child.text_content
          end
          next if custom_attrs.empty?

          context[:html_attributes][path] ||= {}
          context[:html_attributes][path].merge!(custom_attrs)
        end
      end
    end
  end
end
