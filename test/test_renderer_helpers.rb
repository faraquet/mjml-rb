require "minitest/autorun"

require_relative "../lib/mjml-rb"

class RendererHelpersTest < Minitest::Test
  def setup
    @renderer = MjmlRb::Renderer.new
  end

  # --- css_specificity ---
  # css_parser returns integer specificity where IDs=100, classes=10, elements=1

  def test_specificity_element_selector
    assert_equal 1, specificity("p")
  end

  def test_specificity_class_selector
    assert_equal 10, specificity(".foo")
  end

  def test_specificity_id_selector
    assert_equal 100, specificity("#bar")
  end

  def test_specificity_combined
    assert_equal 111, specificity("#bar .foo p")
  end

  def test_specificity_multiple_classes
    assert_equal 20, specificity(".foo.bar")
  end

  def test_specificity_attribute_selector
    assert_equal 10, specificity("[type=text]")
  end

  def test_specificity_pseudo_class
    assert_equal 11, specificity("a:hover")
  end

  def test_specificity_pseudo_element
    assert_equal 2, specificity("p::before")
  end

  def test_specificity_universal_selector
    assert_equal 0, specificity("*")
  end

  def test_specificity_complex_selector
    assert_equal 21, specificity(".container .item a")
  end

  def test_specificity_child_combinator
    assert_equal 2, specificity("div > p")
  end

  def test_specificity_sibling_combinator
    assert_equal 2, specificity("h1 + p")
  end

  def test_specificity_lang_pseudo_class
    assert_equal 10, specificity(":lang(en)")
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

  # --- parse_inline_css_rules skips @-rules ---

  def test_parse_skips_at_media
    rules, _ = parse_css("@media (max-width: 600px) { .x { display: none; } } .y { color: red; }")
    selectors = rules.map(&:first)
    assert_includes selectors, ".y"
    refute selectors.any? { |s| s.include?("@media") }
    refute_includes selectors, ".x"
  end

  def test_parse_skips_at_font_face
    rules, _ = parse_css("@font-face { font-family: 'Custom'; src: url('f.woff2'); } p { color: red; }")
    selectors = rules.map(&:first)
    assert_includes selectors, "p"
    refute selectors.any? { |s| s.include?("@font-face") }
  end

  def test_parse_handles_no_at_rules
    rules, _ = parse_css(".a { color: red; } .b { color: blue; }")
    selectors = rules.map(&:first)
    assert_includes selectors, ".a"
    assert_includes selectors, ".b"
  end

  # --- css_parser strips comments automatically ---

  def test_parse_strips_single_line_comment
    rules, _ = parse_css("p { /* comment */ color: red; }")
    assert_equal "red", rules.first[1]["color"][:value]
  end

  def test_parse_strips_multiline_comment
    css = "p {\n/* multi\nline\ncomment */\ncolor: red;\n}"
    rules, _ = parse_css(css)
    assert_equal "red", rules.first[1]["color"][:value]
  end

  # --- merge_css_declaration ---

  def test_merge_nil_existing_returns_incoming
    result = merge_declaration(nil, { value: "red", important: false })
    assert_equal "red", result[:value]
  end

  def test_merge_important_existing_not_overridden_by_normal
    existing = { value: "blue", important: true, source: :css }
    incoming = { value: "red", important: false, source: :css }
    result = merge_declaration(existing, incoming)
    assert_equal "blue", result[:value]
  end

  def test_merge_important_incoming_overrides_important_existing
    existing = { value: "blue", important: true, source: :css }
    incoming = { value: "red", important: true, source: :css }
    result = merge_declaration(existing, incoming)
    assert_equal "red", result[:value]
  end

  def test_merge_normal_incoming_overrides_normal_existing
    existing = { value: "blue", important: false, source: :css }
    incoming = { value: "red", important: false, source: :css }
    result = merge_declaration(existing, incoming)
    assert_equal "red", result[:value]
  end

  def test_merge_inline_existing_not_overridden_by_normal_stylesheet
    existing = { value: "15px", important: false, source: :inline }
    incoming = { value: "30px", important: false, source: :css }
    result = merge_declaration(existing, incoming)
    assert_equal "15px", result[:value]
  end

  def test_merge_important_stylesheet_overrides_normal_inline
    existing = { value: "15px", important: false, source: :inline }
    incoming = { value: "30px", important: true, source: :css }
    result = merge_declaration(existing, incoming)
    assert_equal "30px", result[:value]
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

  def test_serialize_places_padding_shorthand_before_padding_longhands
    declarations = {
      "padding-bottom" => { value: "0", important: true },
      "background-color" => { value: "#fff", important: false },
      "padding" => { value: "3px 10px", important: false }
    }

    result = serialize_declarations(declarations)
    assert_operator result.index("padding: 3px 10px"), :<, result.index("padding-bottom: 0")
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

  # --- Nokogiri native void tag handling ---
  # Nokogiri's to_html / inner_html natively self-closes void elements
  # and keeps non-void elements with explicit close tags.

  def test_nokogiri_self_closes_br
    fragment = Nokogiri::HTML::DocumentFragment.parse("<div><br></div>")
    assert_match %r{<br\s*/?>}, fragment.at("div").inner_html
  end

  def test_nokogiri_self_closes_img
    fragment = Nokogiri::HTML::DocumentFragment.parse('<div><img src="x.png"></div>')
    html = fragment.at("div").inner_html
    assert_match %r{<img\s}, html
    refute_match %r{</img>}, html
  end

  def test_nokogiri_does_not_self_close_div
    fragment = Nokogiri::HTML::DocumentFragment.parse("<div><div></div></div>")
    assert_includes fragment.at("div").inner_html, "</div>"
  end

  def test_nokogiri_does_not_self_close_td
    fragment = Nokogiri::HTML::DocumentFragment.parse("<table><tr><td></td></tr></table>")
    assert_includes fragment.at("tr").inner_html, "</td>"
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

  def merge_declaration(existing, incoming)
    @renderer.send(:merge_css_declaration, existing, incoming)
  end

  def serialize_declarations(declarations)
    @renderer.send(:serialize_css_declarations, declarations)
  end
end
