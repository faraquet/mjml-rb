require "minitest/autorun"

require_relative "../lib/mjml-rb"

# Verify that all components follow the unified constant naming convention
# and that Base correctly resolves TAGS, ALLOWED_ATTRIBUTES, DEFAULT_ATTRIBUTES.
class ComponentPatternsTest < Minitest::Test
  COMPONENT_CLASSES = [
    MjmlRb::Components::Accordion,
    MjmlRb::Components::Attributes,
    MjmlRb::Components::Body,
    MjmlRb::Components::Breakpoint,
    MjmlRb::Components::Button,
    MjmlRb::Components::Carousel,
    MjmlRb::Components::CarouselImage,
    MjmlRb::Components::Column,
    MjmlRb::Components::Divider,
    MjmlRb::Components::Group,
    MjmlRb::Components::Head,
    MjmlRb::Components::Hero,
    MjmlRb::Components::HtmlAttributes,
    MjmlRb::Components::Image,
    MjmlRb::Components::Navbar,
    MjmlRb::Components::Raw,
    MjmlRb::Components::Section,
    MjmlRb::Components::Social,
    MjmlRb::Components::Spacer,
    MjmlRb::Components::Table,
    MjmlRb::Components::Text,
  ].freeze

  # --- No component uses the old DEFAULTS constant ---

  def test_no_component_uses_old_defaults_constant
    COMPONENT_CLASSES.each do |klass|
      refute klass.const_defined?(:DEFAULTS, false),
        "#{klass} still defines DEFAULTS — rename to DEFAULT_ATTRIBUTES"
    end
  end

  # --- Every component with defaults uses DEFAULT_ATTRIBUTES ---

  COMPONENTS_WITH_DEFAULTS = [
    MjmlRb::Components::Accordion,
    MjmlRb::Components::Body,
    MjmlRb::Components::Breakpoint,
    MjmlRb::Components::Button,
    MjmlRb::Components::Carousel,
    MjmlRb::Components::CarouselImage,
    MjmlRb::Components::Column,
    MjmlRb::Components::Divider,
    MjmlRb::Components::Group,
    MjmlRb::Components::Hero,
    MjmlRb::Components::Image,
    MjmlRb::Components::Section,
    MjmlRb::Components::Spacer,
    MjmlRb::Components::Table,
    MjmlRb::Components::Text,
  ].freeze

  def test_components_with_defaults_define_default_attributes
    COMPONENTS_WITH_DEFAULTS.each do |klass|
      assert klass.const_defined?(:DEFAULT_ATTRIBUTES, false),
        "#{klass} should define DEFAULT_ATTRIBUTES"
      assert_instance_of Hash, klass::DEFAULT_ATTRIBUTES
    end
  end

  # --- All TAGS are frozen arrays of strings ---

  def test_all_tags_are_frozen_string_arrays
    COMPONENT_CLASSES.each do |klass|
      next unless klass.const_defined?(:TAGS, false)

      tags = klass::TAGS
      assert_instance_of Array, tags, "#{klass}::TAGS should be an Array"
      assert tags.frozen?, "#{klass}::TAGS should be frozen"
      tags.each do |tag|
        assert_instance_of String, tag, "#{klass}::TAGS should contain Strings"
        assert tag.start_with?("mj-"), "#{klass}::TAGS should contain mj-* tags, got #{tag}"
      end
    end
  end

  # --- Base.tags delegates to TAGS constant ---

  def test_class_tags_matches_tags_constant
    COMPONENT_CLASSES.each do |klass|
      next unless klass.const_defined?(:TAGS, false)
      assert_equal klass::TAGS, klass.tags, "#{klass}.tags should equal #{klass}::TAGS"
    end
  end

  # --- Base.default_attributes delegates to DEFAULT_ATTRIBUTES ---

  def test_class_default_attributes_resolves_correctly
    COMPONENTS_WITH_DEFAULTS.each do |klass|
      assert_equal klass::DEFAULT_ATTRIBUTES, klass.default_attributes,
        "#{klass}.default_attributes should equal #{klass}::DEFAULT_ATTRIBUTES"
    end
  end

  # --- Instance tags delegates to class tags ---

  def test_instance_tags_delegates_to_class
    renderer = MjmlRb::Renderer.new
    COMPONENT_CLASSES.each do |klass|
      instance = klass.new(renderer)
      assert_equal klass.tags, instance.tags,
        "#{klass}#tags should equal #{klass}.tags"
    end
  end

  # --- No redundant instance def tags in subclasses ---
  # (Base already defines it; subclasses shouldn't override)

  def test_no_redundant_instance_tags_override
    COMPONENT_CLASSES.each do |klass|
      # Check if the class defines its own instance #tags method
      # (not inherited from Base)
      next if klass == MjmlRb::Components::Base

      has_own = klass.instance_method(:tags).owner == klass
      refute has_own,
        "#{klass} defines its own #tags method — remove it, Base#tags already handles TAGS"
    end
  end

  # --- Compilation still works for all key components ---

  def test_button_compiles_after_rename
    result = compile(<<~MJML)
      <mjml><mj-body><mj-section><mj-column>
        <mj-button href="#">Click</mj-button>
      </mj-column></mj-section></mj-body></mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, "Click"
  end

  def test_image_compiles_after_rename
    result = compile(<<~MJML)
      <mjml><mj-body><mj-section><mj-column>
        <mj-image src="test.jpg" />
      </mj-column></mj-section></mj-body></mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, "test.jpg"
  end

  def test_divider_compiles_after_rename
    result = compile(<<~MJML)
      <mjml><mj-body><mj-section><mj-column>
        <mj-divider />
      </mj-column></mj-section></mj-body></mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, "border-top"
  end

  def test_text_compiles_after_rename
    result = compile(<<~MJML)
      <mjml><mj-body><mj-section><mj-column>
        <mj-text>Hello World</mj-text>
      </mj-column></mj-section></mj-body></mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, "Hello World"
  end

  def test_table_compiles_after_rename
    result = compile(<<~MJML)
      <mjml><mj-body><mj-section><mj-column>
        <mj-table><tr><td>Cell</td></tr></mj-table>
      </mj-column></mj-section></mj-body></mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, "Cell"
  end

  def test_accordion_compiles_after_rename
    result = compile(<<~MJML)
      <mjml><mj-body><mj-section><mj-column>
        <mj-accordion>
          <mj-accordion-element>
            <mj-accordion-title>Title</mj-accordion-title>
            <mj-accordion-text>Content</mj-accordion-text>
          </mj-accordion-element>
        </mj-accordion>
      </mj-column></mj-section></mj-body></mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, "Title"
  end

  def test_social_compiles_after_rename
    result = compile(<<~MJML)
      <mjml><mj-body><mj-section><mj-column>
        <mj-social>
          <mj-social-element name="facebook" href="https://facebook.com">Facebook</mj-social-element>
        </mj-social>
      </mj-column></mj-section></mj-body></mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, "Facebook"
  end

  private

  def compile(mjml)
    MjmlRb::Compiler.new.compile(mjml)
  end
end
