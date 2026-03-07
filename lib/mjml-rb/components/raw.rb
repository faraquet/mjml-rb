require_relative "base"

module MjmlRb
  module Components
    class Raw < Base
      TAGS = ["mj-raw"].freeze

      ALLOWED_ATTRIBUTES = {
        "position" => "enum(file-start)"
      }.freeze

      def tags
        TAGS
      end

      def render(tag_name:, node:, context:, attrs:, parent:)
        raw_inner(node)
      end

      def handle_head(node, context)
        context[:head_raw] << raw_inner(node)
      end
    end
  end
end
