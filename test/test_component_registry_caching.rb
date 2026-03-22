require "minitest/autorun"

require_relative "../lib/mjml-rb"

class ComponentRegistryCachingTest < Minitest::Test
  def setup
    @registry = MjmlRb::ComponentRegistry.new
  end

  # --- Cache behavior ---

  def test_tag_class_cache_is_memoized
    first = @registry.component_class_for_tag("mj-text")
    second = @registry.component_class_for_tag("mj-text")
    assert_same first, second
  end

  def test_dependency_rules_cache_is_memoized
    first = @registry.dependency_rules
    second = @registry.dependency_rules
    assert_same first, second
  end

  def test_ending_tags_cache_is_memoized
    first = @registry.ending_tags
    second = @registry.ending_tags
    assert_same first, second
  end

  # --- Cache invalidation on register ---

  def test_register_invalidates_tag_class_cache
    # Warm the cache
    @registry.component_class_for_tag("mj-text")

    klass = build_component("mj-new-tag")
    @registry.register(klass)

    found = @registry.component_class_for_tag("mj-new-tag")
    assert_equal klass, found
  end

  def test_register_invalidates_dependency_rules_cache
    # Warm the cache
    @registry.dependency_rules

    klass = build_component("mj-new-tag")
    @registry.register(klass, dependencies: { "mj-column" => ["mj-new-tag"] })

    rules = @registry.dependency_rules
    assert_includes rules["mj-column"], "mj-new-tag"
  end

  def test_register_invalidates_ending_tags_cache
    # Warm the cache
    @registry.ending_tags

    klass = build_component("mj-new-tag")
    @registry.register(klass, ending_tags: ["mj-new-tag"])

    assert_includes @registry.ending_tags, "mj-new-tag"
  end

  # --- Cache invalidation on reset ---

  def test_reset_invalidates_all_caches
    klass = build_component("mj-temp")
    @registry.register(klass, dependencies: { "mj-column" => ["mj-temp"] }, ending_tags: ["mj-temp"])

    # Warm caches
    @registry.component_class_for_tag("mj-temp")
    @registry.dependency_rules
    @registry.ending_tags

    @registry.reset!

    assert_nil @registry.component_class_for_tag("mj-temp")
    refute_includes @registry.dependency_rules.fetch("mj-column", []), "mj-temp"
    refute_includes @registry.ending_tags, "mj-temp"
  end

  # --- Builtin component lookups ---

  def test_all_builtin_components_are_found
    expected_tags = %w[
      mj-body mj-head mj-attributes mj-breakpoint mj-accordion
      mj-button mj-carousel mj-carousel-image mj-group mj-hero
      mj-image mj-navbar mj-raw mj-text mj-divider
      mj-html-attributes mj-table mj-social mj-section mj-column
      mj-spacer
    ]
    expected_tags.each do |tag|
      refute_nil @registry.component_class_for_tag(tag), "Expected to find component for #{tag}"
    end
  end

  def test_unknown_tag_returns_nil
    assert_nil @registry.component_class_for_tag("mj-nonexistent")
  end

  # --- Dependency rules contain all builtin rules ---

  def test_dependency_rules_contain_all_builtin_keys
    rules = @registry.dependency_rules
    MjmlRb::Dependencies::RULES.each_key do |key|
      assert rules.key?(key), "Expected dependency rules to include #{key}"
    end
  end

  # --- Ending tags contain all builtin tags ---

  def test_ending_tags_contain_all_builtin_ending_tags
    ending = @registry.ending_tags
    MjmlRb::Dependencies::ENDING_TAGS.each do |tag|
      assert ending.include?(tag), "Expected ending tags to include #{tag}"
    end
  end

  # --- Multiple registrations merge dependencies ---

  def test_multiple_registrations_merge_dependencies_for_same_parent
    klass1 = build_component("mj-ext1")
    klass2 = build_component("mj-ext2")

    @registry.register(klass1, dependencies: { "mj-column" => ["mj-ext1"] })
    @registry.register(klass2, dependencies: { "mj-column" => ["mj-ext2"] })

    rules = @registry.dependency_rules
    assert_includes rules["mj-column"], "mj-ext1"
    assert_includes rules["mj-column"], "mj-ext2"
  end

  # --- Custom ending tags merge with builtins ---

  def test_custom_ending_tags_merge_with_builtins
    klass = build_component("mj-custom-ending")
    @registry.register(klass, ending_tags: ["mj-custom-ending"])

    ending = @registry.ending_tags
    assert_includes ending, "mj-custom-ending"
    assert_includes ending, "mj-text" # builtin
    assert_includes ending, "mj-button" # builtin
  end

  private

  def build_component(tag_name)
    Class.new(MjmlRb::Components::Base) do
      const_set(:TAGS, [tag_name].freeze)
      const_set(:ALLOWED_ATTRIBUTES, {}.freeze)

      def render(tag_name:, node:, context:, attrs:, parent:)
        "<div>custom</div>"
      end
    end
  end
end
