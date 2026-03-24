require "minitest/autorun"

require_relative "../lib/mjml-rb"

class HtmlEntitiesTest < Minitest::Test
  # --- Map completeness ---

  def test_entity_map_is_frozen
    assert MjmlRb::HTML_ENTITIES.frozen?
  end

  def test_entity_map_contains_nbsp
    assert_equal 160, MjmlRb::HTML_ENTITIES["nbsp"]
  end

  def test_entity_map_contains_common_entities
    expected = {
      "nbsp"   => 160,
      "copy"   => 169,
      "reg"    => 174,
      "trade"  => 8482,
      "euro"   => 8364,
      "mdash"  => 8212,
      "ndash"  => 8211,
      "laquo"  => 171,
      "raquo"  => 187,
      "bull"   => 8226,
      "hellip" => 8230,
      "deg"    => 176,
      "times"  => 215,
      "divide" => 247,
      "plusmn" => 177
    }

    expected.each do |name, codepoint|
      assert_equal codepoint, MjmlRb::HTML_ENTITIES[name],
        "Expected &#{name}; to map to &##{codepoint};"
    end
  end

  def test_entity_map_does_not_include_xml_predefined_entities
    %w[amp lt gt quot apos].each do |name|
      refute MjmlRb::HTML_ENTITIES.key?(name),
        "XML predefined entity &#{name}; should not be in HTML_ENTITIES map"
    end
  end

  def test_all_codepoints_are_positive_integers
    MjmlRb::HTML_ENTITIES.each do |name, codepoint|
      assert_kind_of Integer, codepoint, "Codepoint for &#{name}; should be an Integer"
      assert_operator codepoint, :>, 0, "Codepoint for &#{name}; should be positive"
    end
  end

  def test_no_duplicate_codepoints_for_different_case_variants
    # Some entities have case variants (e.g. &Agrave; vs &agrave;) -
    # these should map to different codepoints
    lowercase = MjmlRb::HTML_ENTITIES.select { |k, _| k =~ /\A[a-z]/ }
    uppercase = MjmlRb::HTML_ENTITIES.select { |k, _| k =~ /\A[A-Z]/ }

    uppercase.each do |upper_name, upper_cp|
      lower_name = upper_name.downcase
      next unless lowercase.key?(lower_name)

      refute_equal upper_cp, lowercase[lower_name],
        "&#{upper_name}; and &#{lower_name}; should have different codepoints"
    end
  end

  # --- Latin-1 supplement coverage ---

  def test_latin1_accented_characters
    entities = {
      "Agrave" => 192, "agrave" => 224,
      "Eacute" => 201, "eacute" => 233,
      "Icirc"  => 206, "icirc"  => 238,
      "Ouml"   => 214, "ouml"   => 246,
      "Uuml"   => 220, "uuml"   => 252,
      "Ntilde" => 209, "ntilde" => 241,
      "Ccedil" => 199, "ccedil" => 231,
      "szlig"  => 223, "yuml"   => 255
    }

    entities.each do |name, codepoint|
      assert_equal codepoint, MjmlRb::HTML_ENTITIES[name],
        "Expected &#{name}; to map to &##{codepoint};"
    end
  end

  # --- Greek letters ---

  def test_greek_letters
    assert_equal 913, MjmlRb::HTML_ENTITIES["Alpha"]
    assert_equal 945, MjmlRb::HTML_ENTITIES["alpha"]
    assert_equal 937, MjmlRb::HTML_ENTITIES["Omega"]
    assert_equal 969, MjmlRb::HTML_ENTITIES["omega"]
    assert_equal 960, MjmlRb::HTML_ENTITIES["pi"]
  end

  # --- Punctuation and symbols ---

  def test_punctuation_entities
    entities = {
      "lsquo"  => 8216, "rsquo"  => 8217,
      "ldquo"  => 8220, "rdquo"  => 8221,
      "dagger" => 8224, "Dagger" => 8225,
      "permil" => 8240, "prime"  => 8242,
      "lsaquo" => 8249, "rsaquo" => 8250
    }

    entities.each do |name, codepoint|
      assert_equal codepoint, MjmlRb::HTML_ENTITIES[name],
        "Expected &#{name}; to map to &##{codepoint};"
    end
  end

  # --- Arrow symbols ---

  def test_arrow_entities
    assert_equal 8592, MjmlRb::HTML_ENTITIES["larr"]
    assert_equal 8594, MjmlRb::HTML_ENTITIES["rarr"]
    assert_equal 8593, MjmlRb::HTML_ENTITIES["uarr"]
    assert_equal 8595, MjmlRb::HTML_ENTITIES["darr"]
  end

  # --- Math operators ---

  def test_math_operator_entities
    assert_equal 8804, MjmlRb::HTML_ENTITIES["le"]
    assert_equal 8805, MjmlRb::HTML_ENTITIES["ge"]
    assert_equal 8734, MjmlRb::HTML_ENTITIES["infin"]
    assert_equal 8721, MjmlRb::HTML_ENTITIES["sum"]
    assert_equal 8719, MjmlRb::HTML_ENTITIES["prod"]
  end

  # --- Card suit symbols ---

  def test_card_suit_entities
    assert_equal 9824, MjmlRb::HTML_ENTITIES["spades"]
    assert_equal 9827, MjmlRb::HTML_ENTITIES["clubs"]
    assert_equal 9829, MjmlRb::HTML_ENTITIES["hearts"]
    assert_equal 9830, MjmlRb::HTML_ENTITIES["diams"]
  end
end
