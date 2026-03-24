require "minitest/autorun"

require_relative "../lib/mjml-rb"

class HtmlEntitiesTest < Minitest::Test
  def setup
    @parser = MjmlRb::Parser.new
  end

  # --- Nokogiri entity lookup coverage ---

  def test_nokogiri_lookup_contains_nbsp
    assert_equal 160, Nokogiri::HTML::NamedCharacters["nbsp"]
  end

  def test_nokogiri_lookup_contains_common_entities
    expected = {
      "nbsp"   => 160,  "copy"   => 169,  "reg"    => 174,
      "trade"  => 8482, "euro"   => 8364, "mdash"  => 8212,
      "ndash"  => 8211, "laquo"  => 171,  "raquo"  => 187,
      "bull"   => 8226, "hellip" => 8230, "deg"    => 176,
      "times"  => 215,  "divide" => 247,  "plusmn" => 177
    }

    expected.each do |name, codepoint|
      assert_equal codepoint, Nokogiri::HTML::NamedCharacters[name],
        "Expected &#{name}; to resolve to &##{codepoint};"
    end
  end

  def test_nokogiri_lookup_includes_xml_predefined_entities
    # Nokogiri knows these too; the parser skips them via XML_PREDEFINED_ENTITIES
    %w[amp lt gt quot apos].each do |name|
      refute_nil Nokogiri::HTML::NamedCharacters[name],
        "Nokogiri should know &#{name};"
    end
  end

  # --- replace_html_entities integration ---

  def test_replaces_nbsp
    assert_equal "Hello&#160;World", @parser.send(:replace_html_entities, "Hello&nbsp;World")
  end

  def test_replaces_multiple_different_entities
    result = @parser.send(:replace_html_entities, "&copy; 2024 &mdash; all&nbsp;rights")
    assert_equal "&#169; 2024 &#8212; all&#160;rights", result
  end

  def test_preserves_xml_predefined_entities
    content = "&amp; &lt; &gt; &quot; &apos;"
    assert_equal content, @parser.send(:replace_html_entities, content)
  end

  def test_preserves_numeric_decimal_entities
    content = "&#160; &#169;"
    assert_equal content, @parser.send(:replace_html_entities, content)
  end

  def test_preserves_numeric_hex_entities
    content = "&#x20; &#xA0;"
    assert_equal content, @parser.send(:replace_html_entities, content)
  end

  def test_preserves_unknown_entities
    content = "&notarealentity;"
    assert_equal content, @parser.send(:replace_html_entities, content)
  end

  def test_latin1_accented_characters
    entities = {
      "Agrave" => 192, "agrave" => 224,
      "Eacute" => 201, "eacute" => 233,
      "Icirc"  => 206, "icirc"  => 238,
      "Ouml"   => 214, "ouml"   => 246,
      "Ntilde" => 209, "ntilde" => 241,
      "Ccedil" => 199, "ccedil" => 231,
      "szlig"  => 223, "yuml"   => 255
    }

    entities.each do |name, codepoint|
      assert_equal "&##{codepoint};", @parser.send(:replace_html_entities, "&#{name};"),
        "Expected &#{name}; to become &##{codepoint};"
    end
  end

  def test_greek_letters
    {
      "Alpha" => 913, "alpha" => 945,
      "Omega" => 937, "omega" => 969,
      "pi"    => 960
    }.each do |name, codepoint|
      assert_equal "&##{codepoint};", @parser.send(:replace_html_entities, "&#{name};")
    end
  end

  def test_punctuation_entities
    {
      "lsquo" => 8216, "rsquo"  => 8217,
      "ldquo" => 8220, "rdquo"  => 8221,
      "dagger" => 8224, "Dagger" => 8225
    }.each do |name, codepoint|
      assert_equal "&##{codepoint};", @parser.send(:replace_html_entities, "&#{name};")
    end
  end

  def test_arrow_entities
    { "larr" => 8592, "rarr" => 8594, "uarr" => 8593, "darr" => 8595 }.each do |name, codepoint|
      assert_equal "&##{codepoint};", @parser.send(:replace_html_entities, "&#{name};")
    end
  end

  def test_math_operator_entities
    { "le" => 8804, "ge" => 8805, "infin" => 8734, "sum" => 8721, "prod" => 8719 }.each do |name, codepoint|
      assert_equal "&##{codepoint};", @parser.send(:replace_html_entities, "&#{name};")
    end
  end

  def test_currency_and_symbol_entities
    { "euro" => 8364, "trade" => 8482, "reg" => 174, "bull" => 8226 }.each do |name, codepoint|
      assert_equal "&##{codepoint};", @parser.send(:replace_html_entities, "&#{name};")
    end
  end

  def test_card_suit_entities
    { "spades" => 9824, "clubs" => 9827, "hearts" => 9829, "diams" => 9830 }.each do |name, codepoint|
      assert_equal "&##{codepoint};", @parser.send(:replace_html_entities, "&#{name};")
    end
  end
end
