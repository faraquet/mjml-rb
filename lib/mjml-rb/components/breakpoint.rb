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

      def tags
        TAGS
      end

      def render(tag_name:, node:, context:, attrs:, parent:)
        ""
      end
    end
  end
end
