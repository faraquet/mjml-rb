require_relative "base"

module MjmlRb
  module Components
    class HtmlAttributes < Base
      TAGS = %w[mj-selector mj-html-attribute].freeze

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
    end
  end
end
