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
      invalidate_caches!
    end

    def component_class_for_tag(tag_name)
      tag_class_cache[tag_name]
    end

    def dependency_rules
      @dependency_rules_cache ||= begin
        merged = {}
        Dependencies::RULES.each { |k, v| merged[k] = v.dup }
        @custom_dependencies.each do |parent, children|
          merged[parent] = ((merged[parent] || []) + Array(children)).uniq
        end
        merged
      end
    end

    def ending_tags
      @ending_tags_cache ||= (Dependencies::ENDING_TAGS | @custom_ending_tags)
    end

    def reset!
      @custom_components.clear
      @custom_dependencies.clear
      @custom_ending_tags.clear
      invalidate_caches!
    end

    private

    def invalidate_caches!
      @tag_class_cache = nil
      @dependency_rules_cache = nil
      @ending_tags_cache = nil
    end

    def tag_class_cache
      @tag_class_cache ||= all_component_classes.each_with_object({}) do |klass, h|
        klass.tags.each { |tag| h[tag] ||= klass }
      end
    end

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
