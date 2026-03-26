require_relative "base"

module MjmlRb
  module Components
    class Attributes < Base
      TAGS = %w[mj-attributes mj-all mj-class].freeze

      class << self
        def allowed_attributes_for(tag_name)
          {}
        end

        def allowed_attributes
          {}
        end
      end

      def render(tag_name:, node:, context:, attrs:, parent:)
        ""
      end

      def handle_head(attributes_node, context)
        attributes_node.element_children.each do |child|
          case child.tag_name
          when "mj-all"
            context[:global_defaults].merge!(node_string_attributes(child))
          when "mj-class"
            name = child["name"]
            next unless name

            context[:classes][name] ||= {}
            context[:classes][name].merge!(node_string_attributes(child).reject { |key, _| key == "name" })

            defaults = child.element_children.each_with_object({}) do |class_child, memo|
              memo[class_child.tag_name] = node_string_attributes(class_child)
            end
            next if defaults.empty?

            context[:classes_default][name] ||= {}
            context[:classes_default][name].merge!(defaults)
          else
            context[:tag_defaults][child.tag_name] ||= {}
            context[:tag_defaults][child.tag_name].merge!(node_string_attributes(child))
          end
        end
      end
    end
  end
end
