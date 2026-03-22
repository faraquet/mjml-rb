require_relative "base"

module MjmlRb
  module Components
    class Breakpoint < Base
      TAGS = ["mj-breakpoint"].freeze

      ALLOWED_ATTRIBUTES = {
        "width" => "unit(px)"
      }.freeze

      DEFAULT_ATTRIBUTES = {
        "width" => "480px"
      }.freeze

      def render(tag_name:, node:, context:, attrs:, parent:)
        ""
      end

      def handle_head(node, context)
        width = node.attributes["width"].to_s.strip
        context[:breakpoint] = width unless width.empty?
      end
    end
  end
end
