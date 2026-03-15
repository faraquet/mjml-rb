require "set"

module MjmlRb
  class ComponentRegistry
    attr_reader :custom_components, :custom_dependencies, :custom_ending_tags

    def initialize
      @custom_components = []
      @custom_dependencies = {}
      @custom_ending_tags = Set.new
    end

    def register(klass, dependencies: {}, ending_tags: [])
      validate_component!(klass)
      @custom_components << klass unless @custom_components.include?(klass)
      dependencies.each do |parent, children|
        @custom_dependencies[parent] = ((@custom_dependencies[parent] || []) + Array(children)).uniq
      end
      @custom_ending_tags.merge(Array(ending_tags))
    end

    def component_class_for_tag(tag_name)
      all_component_classes.find { |klass| klass.tags.include?(tag_name) }
    end

    def dependency_rules
      merged = {}
      Dependencies::RULES.each { |k, v| merged[k] = v.dup }
      @custom_dependencies.each do |parent, children|
        merged[parent] = ((merged[parent] || []) + Array(children)).uniq
      end
      merged
    end

    def ending_tags
      Dependencies::ENDING_TAGS | @custom_ending_tags
    end

    def reset!
      @custom_components.clear
      @custom_dependencies.clear
      @custom_ending_tags.clear
    end

    private

    def all_component_classes
      builtin = MjmlRb::Components.constants.filter_map do |name|
        value = MjmlRb::Components.const_get(name)
        value if value.is_a?(Class) && value < MjmlRb::Components::Base
      rescue NameError
        nil
      end
      (builtin + @custom_components).uniq
    end

    def validate_component!(klass)
      raise ArgumentError, "Expected a Class, got #{klass.class}" unless klass.is_a?(Class)
      unless klass.respond_to?(:tags) && klass.respond_to?(:allowed_attributes)
        raise ArgumentError, "Component class must respond to .tags and .allowed_attributes (inherit from MjmlRb::Components::Base)"
      end
      raise ArgumentError, "Component must define at least one tag via TAGS" if klass.tags.empty?
    end
  end
end
