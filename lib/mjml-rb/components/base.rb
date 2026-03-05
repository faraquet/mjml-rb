module MjmlRb
  module Components
    class Base
      class << self
        def tags
          const_defined?(:TAGS) ? const_get(:TAGS) : []
        end

        def allowed_attributes
          const_defined?(:ALLOWED_ATTRIBUTES) ? const_get(:ALLOWED_ATTRIBUTES) : {}
        end

        def default_attributes
          if const_defined?(:DEFAULT_ATTRIBUTES)
            const_get(:DEFAULT_ATTRIBUTES)
          elsif const_defined?(:DEFAULTS)
            const_get(:DEFAULTS)
          else
            {}
          end
        end
      end

      def initialize(renderer)
        @renderer = renderer
      end

      def tags
        self.class.tags
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

      # Like raw_inner but HTML-escapes text nodes. Use for components such as
      # mj-text where the inner content is treated as HTML but bare text must
      # be properly encoded (e.g. & -> &amp;).
      def html_inner(node)
        renderer.send(:html_inner, node)
      end

      def escape_html(value)
        renderer.send(:escape_html, value)
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
