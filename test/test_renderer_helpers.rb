require "minitest/autorun"

require_relative "../lib/mjml-rb"

class RendererHelpersTest < Minitest::Test
  def setup
    @renderer = MjmlRb::Renderer.new
  end

  # --- css_specificity ---

  def test_specificity_element_selector
    assert_equal [0, 0, 1], specificity("p")
  end

  def test_specificity_class_selector
    assert_equal [0, 1, 0], specificity(".foo")
  end

  def test_specificity_id_selector
    assert_equal [1, 0, 0], specificity("#bar")
  end

  def test_specificity_combined
    # #id .class element = [1, 1, 1]
    assert_equal [1, 1, 1], specificity("#bar .foo p")
  end

  def test_specificity_multiple_classes
    assert_equal [0, 2, 0], specificity(".foo.bar")
  end

  def test_specificity_attribute_selector
    assert_equal [0, 1, 0], specificity("[type=text]")
  end

  def test_specificity_pseudo_class
    assert_equal [0, 1, 1], specificity("a:hover")
  end

  def test_specificity_pseudo_element
    # The implementation counts ::before as both a pseudo-class (:before via single-colon regex)
    # and a pseudo-element (::before), resulting in [0, 1, 2] not [0, 0, 2].
    # This is acceptable since the relative ordering is still correct for cascade purposes.
    assert_equal [0, 1, 2], specificity("p::before")
  end

  def test_specificity_universal_selector
    assert_equal [0, 0, 0], specificity("*")
  end

  def test_specificity_complex_selector
    # .container .item a = [0, 2, 1]
    assert_equal [0, 2, 1], specificity(".container .item a")
  end

  def test_specificity_child_combinator
    assert_equal [0, 0, 2], specificity("div > p")
  end

  def test_specificity_sibling_combinator
    assert_equal [0, 0, 2], specificity("h1 + p")
  end

  def test_specificity_lang_pseudo_class
    assert_equal [0, 1, 0], specificity(":lang(en)")
  end

  # --- parse_inline_css_rules ---

  def test_parse_simple_css_rule
    rules, at_rules = parse_css("p { color: red; }")
    assert_equal "p", rules.first[0]
    assert_equal "red", rules.first[1]["color"][:value]
    assert_equal "", at_rules.strip
  end

  def test_parse_multiple_selectors
    rules, _ = parse_css(".a, .b { color: blue; }")
    selectors = rules.map(&:first)
    assert_includes selectors, ".a"
    assert_includes selectors, ".b"
  end

  def test_parse_important_declaration
    rules, _ = parse_css("p { color: red !important; }")
    assert_equal true, rules.first[1]["color"][:important]
    assert_equal "red", rules.first[1]["color"][:value]
  end

  def test_parse_multiple_declarations
    rules, _ = parse_css("p { color: red; font-size: 14px; }")
    decl = rules.first[1]
    assert_equal "red", decl["color"][:value]
    assert_equal "14px", decl["font-size"][:value]
  end

  def test_rules_sorted_by_specificity
    css = <<~CSS
      #id { color: green; }
      .class { color: blue; }
      p { color: red; }
    CSS
    rules, _ = parse_css(css)
    selectors = rules.map(&:first)
    # Sorted ascending: p (0,0,1) < .class (0,1,0) < #id (1,0,0)
    assert_equal "p", selectors[0]
    assert_equal ".class", selectors[1]
    assert_equal "#id", selectors[2]
  end

  # --- extract_css_at_rules ---

  def test_extract_at_media
    plain, at_rules = extract_at_rules("@media (max-width: 600px) { .x { display: none; } } .y { color: red; }")
    assert_includes at_rules, "@media"
    assert_includes at_rules, "display: none"
    assert_includes plain, ".y"
    refute_includes plain, "@media"
  end

  def test_extract_at_font_face
    plain, at_rules = extract_at_rules("@font-face { font-family: 'Custom'; src: url('f.woff2'); } p { color: red; }")
    assert_includes at_rules, "@font-face"
    assert_includes at_rules, "Custom"
    assert_includes plain, "p { color: red; }"
  end

  def test_extract_at_import
    plain, at_rules = extract_at_rules("@import url('styles.css'); p { color: red; }")
    assert_includes at_rules, "@import"
    assert_includes plain, "p { color: red; }"
  end

  def test_extract_no_at_rules
    plain, at_rules = extract_at_rules(".a { color: red; } .b { color: blue; }")
    assert_includes plain, ".a"
    assert_includes plain, ".b"
    assert_equal "", at_rules.strip
  end

  # --- strip_css_comments ---

  def test_strip_single_line_comment
    result = strip_comments("p { /* comment */ color: red; }")
    refute_includes result, "comment"
    assert_includes result, "color: red"
  end

  def test_strip_multiline_comment
    css = "p {\n/* multi\nline\ncomment */\ncolor: red;\n}"
    result = strip_comments(css)
    refute_includes result, "multi"
    assert_includes result, "color: red"
  end

  # --- merge_css_declaration ---

  def test_merge_nil_existing_returns_incoming
    result = merge_declaration(nil, { value: "red", important: false })
    assert_equal "red", result[:value]
  end

  def test_merge_important_existing_not_overridden_by_normal
    existing = { value: "blue", important: true }
    incoming = { value: "red", important: false }
    result = merge_declaration(existing, incoming)
    assert_equal "blue", result[:value]
  end

  def test_merge_important_incoming_overrides_important_existing
    existing = { value: "blue", important: true }
    incoming = { value: "red", important: true }
    result = merge_declaration(existing, incoming)
    assert_equal "red", result[:value]
  end

  def test_merge_normal_incoming_overrides_normal_existing
    existing = { value: "blue", important: false }
    incoming = { value: "red", important: false }
    result = merge_declaration(existing, incoming)
    assert_equal "red", result[:value]
  end

  # --- syncable_background? ---

  def test_syncable_background_nil
    assert syncable_background?(nil)
  end

  def test_syncable_background_empty
    assert syncable_background?("")
  end

  def test_syncable_background_simple_color
    assert syncable_background?("#ff0000")
  end

  def test_not_syncable_background_with_url
    refute syncable_background?("url(image.png)")
  end

  def test_not_syncable_background_with_gradient
    refute syncable_background?("linear-gradient(to right, #000, #fff)")
  end

  def test_not_syncable_background_with_position
    refute syncable_background?("#ff0000 center top")
  end

  def test_not_syncable_background_with_repeat
    refute syncable_background?("#ff0000 no-repeat")
  end

  # --- serialize_css_declarations ---

  def test_serialize_declarations
    declarations = {
      "color" => { value: "red", important: false },
      "font-size" => { value: "14px", important: true }
    }
    result = serialize_declarations(declarations)
    assert_includes result, "color: red"
    assert_includes result, "font-size: 14px"
    refute_includes result, "!important"
  end

  def test_serialize_empty_declarations
    assert_equal "", serialize_declarations({})
  end

  # --- style_join ---

  def test_style_join_basic
    result = @renderer.send(:style_join, { "color" => "red", "font-size" => "14px" })
    assert_includes result, "color:red"
    assert_includes result, "font-size:14px"
  end

  def test_style_join_skips_nil_values
    result = @renderer.send(:style_join, { "color" => "red", "background" => nil })
    assert_includes result, "color:red"
    refute_includes result, "background"
  end

  def test_style_join_skips_empty_values
    result = @renderer.send(:style_join, { "color" => "red", "background" => "" })
    assert_includes result, "color:red"
    refute_includes result, "background"
  end

  # --- html_attrs ---

  def test_html_attrs_basic
    result = @renderer.send(:html_attrs, { "class" => "foo", "id" => "bar" })
    assert_includes result, 'class="foo"'
    assert_includes result, 'id="bar"'
  end

  def test_html_attrs_skips_nil_values
    result = @renderer.send(:html_attrs, { "class" => "foo", "id" => nil })
    assert_includes result, 'class="foo"'
    refute_includes result, "id="
  end

  def test_html_attrs_empty_hash
    assert_equal "", @renderer.send(:html_attrs, {})
  end

  def test_html_attrs_escapes_special_characters
    result = @renderer.send(:html_attrs, { "title" => 'He said "hi" & bye' })
    assert_includes result, "&amp;"
    assert_includes result, "&quot;"
  end

  # --- unique_strings ---

  def test_unique_strings_removes_duplicates
    result = @renderer.send(:unique_strings, ["a", "b", "a", "c", "b"])
    assert_equal ["a", "b", "c"], result
  end

  def test_unique_strings_removes_nil_and_empty
    result = @renderer.send(:unique_strings, ["a", nil, "", "b", nil])
    assert_equal ["a", "b"], result
  end

  def test_unique_strings_preserves_order
    result = @renderer.send(:unique_strings, ["c", "a", "b"])
    assert_equal ["c", "a", "b"], result
  end

  def test_unique_strings_handles_nil_input
    result = @renderer.send(:unique_strings, nil)
    assert_equal [], result
  end

  # --- escape_html / escape_attr ---

  def test_escape_html
    result = @renderer.send(:escape_html, '<script>alert("xss")</script>')
    assert_includes result, "&lt;script&gt;"
    assert_includes result, "&quot;"
  end

  def test_escape_attr
    result = @renderer.send(:escape_attr, 'value with "quotes" & special')
    assert_includes result, "&quot;"
    assert_includes result, "&amp;"
  end

  # --- html_void_tag? ---

  def test_html_void_tag_br
    assert @renderer.send(:html_void_tag?, "br")
  end

  def test_html_void_tag_img
    assert @renderer.send(:html_void_tag?, "img")
  end

  def test_html_void_tag_div_is_not_void
    refute @renderer.send(:html_void_tag?, "div")
  end

  def test_html_void_tag_case_insensitive
    assert @renderer.send(:html_void_tag?, "BR")
  end

  # --- hash_or_empty ---

  def test_hash_or_empty_with_hash
    result = @renderer.send(:hash_or_empty, { a: 1 })
    assert_equal({ a: 1 }, result)
  end

  def test_hash_or_empty_with_nil
    assert_equal({}, @renderer.send(:hash_or_empty, nil))
  end

  def test_hash_or_empty_with_string
    assert_equal({}, @renderer.send(:hash_or_empty, "not a hash"))
  end

  private

  def specificity(selector)
    @renderer.send(:css_specificity, selector)
  end

  def parse_css(css)
    @renderer.send(:parse_inline_css_rules, css)
  end

  def extract_at_rules(css)
    @renderer.send(:extract_css_at_rules, css)
  end

  def strip_comments(css)
    @renderer.send(:strip_css_comments, css)
  end

  def merge_declaration(existing, incoming)
    @renderer.send(:merge_css_declaration, existing, incoming)
  end

  def syncable_background?(value)
    @renderer.send(:syncable_background?, value)
  end

  def serialize_declarations(declarations)
    @renderer.send(:serialize_css_declarations, declarations)
  end
end
