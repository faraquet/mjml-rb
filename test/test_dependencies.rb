require "minitest/autorun"

require_relative "../lib/mjml-rb"

class DependenciesTest < Minitest::Test
  def test_rules_is_frozen_hash
    assert_instance_of Hash, MjmlRb::Dependencies::RULES
    assert MjmlRb::Dependencies::RULES.frozen?
  end

  def test_ending_tags_is_frozen_set
    assert_instance_of Set, MjmlRb::Dependencies::ENDING_TAGS
    assert MjmlRb::Dependencies::ENDING_TAGS.frozen?
  end

  def test_ending_tags_contains_expected_tags
    expected = %w[mj-accordion-text mj-accordion-title mj-button mj-carousel-image mj-navbar-link mj-raw mj-table mj-text]
    expected.each do |tag|
      assert MjmlRb::Dependencies::ENDING_TAGS.include?(tag), "Expected ENDING_TAGS to include #{tag}"
    end
  end

  def test_mjml_root_allows_body_head_raw
    allowed = MjmlRb::Dependencies::RULES["mjml"]
    assert_includes allowed, "mj-body"
    assert_includes allowed, "mj-head"
    assert_includes allowed, "mj-raw"
  end

  def test_body_allows_structural_components
    allowed = MjmlRb::Dependencies::RULES["mj-body"]
    assert_includes allowed, "mj-section"
    assert_includes allowed, "mj-wrapper"
    assert_includes allowed, "mj-hero"
    assert_includes allowed, "mj-raw"
  end

  def test_section_allows_column_and_group
    allowed = MjmlRb::Dependencies::RULES["mj-section"]
    assert_includes allowed, "mj-column"
    assert_includes allowed, "mj-group"
    assert_includes allowed, "mj-raw"
  end

  def test_column_allows_content_components
    allowed = MjmlRb::Dependencies::RULES["mj-column"]
    expected = %w[mj-accordion mj-button mj-carousel mj-divider mj-image mj-raw mj-social mj-spacer mj-table mj-text mj-navbar]
    expected.each do |tag|
      assert_includes allowed, tag, "Expected mj-column to allow #{tag}"
    end
  end

  def test_head_allows_head_components
    allowed = MjmlRb::Dependencies::RULES["mj-head"]
    expected = %w[mj-attributes mj-breakpoint mj-html-attributes mj-font mj-preview mj-style mj-title mj-raw]
    expected.each do |tag|
      assert_includes allowed, tag, "Expected mj-head to allow #{tag}"
    end
  end

  def test_wrapper_allows_hero_raw_section
    allowed = MjmlRb::Dependencies::RULES["mj-wrapper"]
    assert_includes allowed, "mj-hero"
    assert_includes allowed, "mj-raw"
    assert_includes allowed, "mj-section"
  end

  def test_carousel_only_allows_carousel_image
    allowed = MjmlRb::Dependencies::RULES["mj-carousel"]
    assert_equal ["mj-carousel-image"], allowed
  end

  def test_leaf_components_have_empty_children
    leaf_tags = %w[mj-accordion-title mj-accordion-text mj-button mj-carousel-image mj-divider mj-image mj-raw mj-spacer mj-table mj-text]
    leaf_tags.each do |tag|
      assert_equal [], MjmlRb::Dependencies::RULES[tag], "Expected #{tag} to have empty children"
    end
  end

  def test_attributes_allows_any_child_via_regex
    allowed = MjmlRb::Dependencies::RULES["mj-attributes"]
    assert_equal 1, allowed.size
    assert_instance_of Regexp, allowed.first
    assert allowed.first.match?("mj-anything")
  end

  def test_all_rules_keys_are_strings
    MjmlRb::Dependencies::RULES.each_key do |key|
      assert_instance_of String, key
    end
  end
end
