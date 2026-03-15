require "minitest/autorun"
require "nokogiri"

require_relative "../lib/mjml-rb"

class ComponentRegistryTest < Minitest::Test
  def setup
    MjmlRb.component_registry.reset!
  end

  def teardown
    MjmlRb.component_registry.reset!
  end

  # ── Registration API ──────────────────────────────────────────────────

  def test_register_component_adds_to_custom_components
    klass = build_custom_component("mj-custom")
    MjmlRb.register_component(klass)
    assert_includes MjmlRb.component_registry.custom_components, klass
  end

  def test_register_component_with_dependencies
    klass = build_custom_component("mj-custom")
    MjmlRb.register_component(klass, dependencies: {"mj-column" => ["mj-custom"]})

    rules = MjmlRb.component_registry.dependency_rules
    assert_includes rules["mj-column"], "mj-custom"
  end

  def test_register_component_with_ending_tags
    klass = build_custom_component("mj-custom")
    MjmlRb.register_component(klass, ending_tags: ["mj-custom"])

    assert_includes MjmlRb.component_registry.ending_tags, "mj-custom"
  end

  def test_register_rejects_non_class
    assert_raises(ArgumentError) { MjmlRb.register_component("not a class") }
  end

  def test_register_rejects_class_without_tags
    klass = Class.new
    assert_raises(ArgumentError) { MjmlRb.register_component(klass) }
  end

  def test_register_rejects_class_with_empty_tags
    klass = Class.new(MjmlRb::Components::Base)
    klass.const_set(:TAGS, [])
    klass.const_set(:ALLOWED_ATTRIBUTES, {})
    assert_raises(ArgumentError) { MjmlRb.register_component(klass) }
  end

  def test_duplicate_registration_is_idempotent
    klass = build_custom_component("mj-custom")
    MjmlRb.register_component(klass)
    MjmlRb.register_component(klass)
    assert_equal 1, MjmlRb.component_registry.custom_components.count(klass)
  end

  def test_reset_clears_custom_components
    klass = build_custom_component("mj-custom")
    MjmlRb.register_component(klass, dependencies: {"mj-column" => ["mj-custom"]}, ending_tags: ["mj-custom"])
    MjmlRb.component_registry.reset!

    assert_empty MjmlRb.component_registry.custom_components
    assert_empty MjmlRb.component_registry.custom_dependencies
    assert_empty MjmlRb.component_registry.custom_ending_tags
  end

  # ── Lookup ─────────────────────────────────────────────────────────────

  def test_component_class_for_tag_finds_builtin
    klass = MjmlRb.component_registry.component_class_for_tag("mj-text")
    assert_equal MjmlRb::Components::Text, klass
  end

  def test_component_class_for_tag_finds_custom
    klass = build_custom_component("mj-custom")
    MjmlRb.register_component(klass)

    found = MjmlRb.component_registry.component_class_for_tag("mj-custom")
    assert_equal klass, found
  end

  def test_component_class_for_tag_returns_nil_for_unknown
    assert_nil MjmlRb.component_registry.component_class_for_tag("mj-unknown")
  end

  # ── Dependency merging ────────────────────────────────────────────────

  def test_dependency_rules_include_builtin
    rules = MjmlRb.component_registry.dependency_rules
    assert_includes rules["mj-body"], "mj-section"
  end

  def test_dependency_rules_merge_custom_additively
    klass = build_custom_component("mj-custom")
    MjmlRb.register_component(klass, dependencies: {"mj-column" => ["mj-custom"]})

    rules = MjmlRb.component_registry.dependency_rules
    assert_includes rules["mj-column"], "mj-custom"
    assert_includes rules["mj-column"], "mj-text"
  end

  def test_ending_tags_include_builtin
    ending = MjmlRb.component_registry.ending_tags
    assert_includes ending, "mj-text"
    assert_includes ending, "mj-button"
  end

  # ── Integration: compile with custom component ────────────────────────

  def test_custom_component_renders_in_mjml
    klass = build_custom_component("mj-custom") do
      def render(tag_name:, node:, context:, attrs:, parent:)
        a = self.class.default_attributes.merge(attrs)
        color = a["color"] || "#000000"
        %(<div class="mj-custom" style="color:#{escape_attr(color)}">Custom Content</div>)
      end
    end

    MjmlRb.register_component(klass, dependencies: {"mj-column" => ["mj-custom"]})

    mjml = <<~MJML
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-custom color="#ff0000">Hello</mj-custom>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    result = MjmlRb.mjml2html(mjml)
    assert_empty result[:errors]
    assert_includes result[:html], "Custom Content"
    assert_includes result[:html], 'class="mj-custom"'
    assert_includes result[:html], "color:#ff0000"
  end

  def test_custom_component_validates_attributes
    klass = build_custom_component("mj-custom")
    MjmlRb.register_component(klass, dependencies: {"mj-column" => ["mj-custom"]})

    mjml = <<~MJML
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-custom unknown-attr="bad">Hello</mj-custom>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    result = MjmlRb.mjml2html(mjml, validation_level: "soft")
    assert result[:errors].any? { |e| e[:message].include?("unknown-attr") }
  end

  def test_custom_component_rejected_without_dependency_rule
    klass = build_custom_component("mj-custom")
    MjmlRb.register_component(klass)

    mjml = <<~MJML
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-custom>Hello</mj-custom>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    result = MjmlRb.mjml2html(mjml, validation_level: "soft")
    assert result[:errors].any? { |e| e[:message].include?("not allowed") }
  end

  private

  def build_custom_component(tag_name, &block)
    klass = Class.new(MjmlRb::Components::Base) do
      const_set(:TAGS, [tag_name].freeze)
      const_set(:ALLOWED_ATTRIBUTES, {"color" => "color"}.freeze)
      const_set(:DEFAULT_ATTRIBUTES, {"color" => "#000000"}.freeze)

      def render(tag_name:, node:, context:, attrs:, parent:)
        %(<div class="mj-custom">Custom Content</div>)
      end
    end
    klass.class_eval(&block) if block
    klass
  end
end
