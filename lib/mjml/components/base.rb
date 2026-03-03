module MJML
  module Components
    class Base
      def initialize(renderer)
        @renderer = renderer
      end

      def tags
        []
      end

      private

      attr_reader :renderer

      def render_node(node, context, parent:)
        renderer.send(:render_node, node, context, parent: parent)
      end

      def render_children(node, context, parent:)
        renderer.send(:render_children, node, context, parent: parent)
      end

      def resolved_attributes(node, context)
        renderer.send(:resolved_attributes, node, context)
      end

      def raw_inner(node)
        renderer.send(:raw_inner, node)
      end

      def style_join(hash)
        renderer.send(:style_join, hash)
      end

      def escape_attr(value)
        renderer.send(:escape_attr, value)
      end

      def html_attrs(hash)
        renderer.send(:html_attrs, hash)
      end
    end
  end
end
