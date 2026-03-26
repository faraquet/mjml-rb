require "minitest/autorun"

require_relative "../lib/mjml-rb"

class ParserTest < Minitest::Test
  def setup
    @parser = MjmlRb::Parser.new
  end

  # --- Basic parsing ---

  def test_parse_minimal_mjml
    ast = @parser.parse("<mjml><mj-body></mj-body></mjml>")
    assert_equal "mjml", ast.tag_name
    body = ast.element_children.find { |c| c.tag_name == "mj-body" }
    refute_nil body
  end

  def test_parse_returns_nokogiri_node
    ast = @parser.parse("<mjml><mj-body></mj-body></mjml>")
    assert_kind_of Nokogiri::XML::Node, ast
  end

  def test_parse_preserves_attributes
    ast = @parser.parse('<mjml><mj-body background-color="#ffffff"></mj-body></mjml>')
    body = ast.element_children.find { |c| c.tag_name == "mj-body" }
    assert_equal "#ffffff", body["background-color"]
  end

  # --- Text content ---

  def test_parse_text_children
    ast = @parser.parse("<mjml><mj-body><mj-section><mj-column><mj-text>Hello World</mj-text></mj-column></mj-section></mj-body></mjml>")
    # mj-text is an ending tag, so content is stored directly
    section = ast.element_children.find { |c| c.tag_name == "mj-body" }
    refute_nil section
  end

  # --- CDATA wrapping for ending tags ---

  def test_ending_tags_preserve_html_content
    mjml = <<~MJML
      <mjml><mj-body><mj-section><mj-column>
        <mj-text><p>Hello <strong>World</strong></p></mj-text>
      </mj-column></mj-section></mj-body></mjml>
    MJML
    ast = @parser.parse(mjml)

    # Walk to mj-text
    body = ast.element_children.find { |c| c.tag_name == "mj-body" }
    section = body.element_children.find { |c| c.tag_name == "mj-section" }
    column = section.element_children.find { |c| c.tag_name == "mj-column" }
    text = column.element_children.find { |c| c.tag_name == "mj-text" }

    refute_nil text
    assert_includes text.content, "<p>"
    assert_includes text.content, "<strong>World</strong>"
  end

  def test_button_ending_tag_preserves_inner_html
    mjml = <<~MJML
      <mjml><mj-body><mj-section><mj-column>
        <mj-button href="https://example.com">Click <b>here</b></mj-button>
      </mj-column></mj-section></mj-body></mjml>
    MJML
    ast = @parser.parse(mjml)
    body = ast.element_children.find { |c| c.tag_name == "mj-body" }
    section = body.element_children.find { |c| c.tag_name == "mj-section" }
    column = section.element_children.find { |c| c.tag_name == "mj-column" }
    button = column.element_children.find { |c| c.tag_name == "mj-button" }

    refute_nil button
    assert_includes button.content, "Click"
    assert_includes button.content, "<b>here</b>"
  end

  def test_nested_same_ending_tags_preserve_full_outer_content
    mjml = <<~MJML
      <mjml><mj-body><mj-section><mj-column>
        <mj-text>
          <div>Outer</div>
          <mj-section><mj-column><mj-text>Inner</mj-text></mj-column></mj-section>
        </mj-text>
      </mj-column></mj-section></mj-body></mjml>
    MJML

    ast = @parser.parse(mjml)
    body = ast.element_children.find { |c| c.tag_name == "mj-body" }
    section = body.element_children.find { |c| c.tag_name == "mj-section" }
    column = section.element_children.find { |c| c.tag_name == "mj-column" }
    text = column.element_children.find { |c| c.tag_name == "mj-text" }

    refute_nil text
    assert_includes text.content, "<div>Outer</div>"
    assert_includes text.content, "<mj-section>"
    assert_includes text.content, "<mj-text>Inner</mj-text>"
  end

  # --- HTML void tags ---

  def test_void_tags_are_self_closed
    mjml = <<~MJML
      <mjml><mj-body><mj-section><mj-column>
        <mj-text><br><hr><img src="test.jpg"></mj-text>
      </mj-column></mj-section></mj-body></mjml>
    MJML
    # Should not raise XML parse error
    ast = @parser.parse(mjml)
    refute_nil ast
  end

  def test_closing_br_tag_is_normalized
    mjml = <<~MJML
      <mjml><mj-body><mj-section><mj-column>
        <mj-text>Line 1</br>Line 2</mj-text>
      </mj-column></mj-section></mj-body></mjml>
    MJML
    ast = @parser.parse(mjml)
    refute_nil ast
  end

  def test_closing_hr_tag_is_removed
    mjml = <<~MJML
      <mjml><mj-body><mj-section><mj-column>
        <mj-text><hr></hr></mj-text>
      </mj-column></mj-section></mj-body></mjml>
    MJML
    ast = @parser.parse(mjml)
    refute_nil ast
  end

  # --- Bare ampersands ---

  def test_bare_ampersands_are_sanitized
    mjml = <<~MJML
      <mjml><mj-body><mj-section><mj-column>
        <mj-text>Terms & Conditions</mj-text>
      </mj-column></mj-section></mj-body></mjml>
    MJML
    ast = @parser.parse(mjml)
    refute_nil ast
  end

  def test_valid_entity_references_are_preserved
    mjml = <<~MJML
      <mjml><mj-body><mj-section><mj-column>
        <mj-text>Hello &amp; World &#123; &#x1F;</mj-text>
      </mj-column></mj-section></mj-body></mjml>
    MJML
    ast = @parser.parse(mjml)
    refute_nil ast
  end

  # --- HTML named entity replacement ---

  def test_nbsp_entity_is_parsed
    mjml = <<~MJML
      <mjml><mj-body><mj-section><mj-column>
        <mj-text>Hello&nbsp;World</mj-text>
      </mj-column></mj-section></mj-body></mjml>
    MJML
    ast = @parser.parse(mjml)
    text = walk_to_first(ast, "mj-text")
    refute_nil text
    assert_includes text.content, "Hello"
    assert_includes text.content, "World"
  end

  def test_multiple_nbsp_entities_in_one_element
    mjml = <<~MJML
      <mjml><mj-body><mj-section><mj-column>
        <mj-text>A&nbsp;B&nbsp;C&nbsp;D</mj-text>
      </mj-column></mj-section></mj-body></mjml>
    MJML
    ast = @parser.parse(mjml)
    text = walk_to_first(ast, "mj-text")
    refute_nil text
    # All four words should survive parsing
    %w[A B C D].each { |w| assert_includes text.content, w }
  end

  def test_common_html_entities_are_parsed
    mjml = <<~MJML
      <mjml><mj-body><mj-section><mj-column>
        <mj-text>&copy; 2024 &mdash; All&nbsp;rights &laquo;reserved&raquo;</mj-text>
      </mj-column></mj-section></mj-body></mjml>
    MJML
    # Should not raise - all HTML entities converted to numeric equivalents
    ast = @parser.parse(mjml)
    text = walk_to_first(ast, "mj-text")
    refute_nil text
    assert_includes text.content, "2024"
    assert_includes text.content, "rights"
    assert_includes text.content, "reserved"
  end

  def test_html_entities_converted_to_numeric_equivalents
    # Verify that HTML entities are converted to their numeric form
    parser = MjmlRb::Parser.new
    content = "Hello&nbsp;World &copy; &mdash;"
    converted = parser.send(:replace_html_entities, content)
    assert_equal "Hello&#160;World &#169; &#8212;", converted
  end

  def test_xml_predefined_entities_are_not_replaced
    parser = MjmlRb::Parser.new
    content = "&amp; &lt; &gt; &quot; &apos;"
    converted = parser.send(:replace_html_entities, content)
    assert_equal "&amp; &lt; &gt; &quot; &apos;", converted
  end

  def test_numeric_entities_are_not_replaced
    parser = MjmlRb::Parser.new
    content = "&#160; &#x20; &#xA0;"
    converted = parser.send(:replace_html_entities, content)
    assert_equal "&#160; &#x20; &#xA0;", converted
  end

  def test_unknown_named_entity_is_left_as_is
    parser = MjmlRb::Parser.new
    content = "&notarealentity;"
    converted = parser.send(:replace_html_entities, content)
    assert_equal "&notarealentity;", converted
  end

  def test_mixed_html_and_xml_entities
    mjml = <<~MJML
      <mjml><mj-body><mj-section><mj-column>
        <mj-text>A &amp; B &nbsp; C &lt; D &copy; E</mj-text>
      </mj-column></mj-section></mj-body></mjml>
    MJML
    ast = @parser.parse(mjml)
    text = walk_to_first(ast, "mj-text")
    refute_nil text
  end

  def test_html_entities_in_non_ending_tag_attributes
    mjml = <<~MJML
      <mjml><mj-body>
        <mj-section background-color="#ffffff">
          <mj-column>
            <mj-text>Test</mj-text>
          </mj-column>
        </mj-section>
      </mj-body></mjml>
    MJML
    ast = @parser.parse(mjml)
    refute_nil ast
  end

  def test_html_entities_outside_cdata_wrapped_tags
    # Entities in mj-section (not an ending tag, so not CDATA-wrapped)
    # should still be handled by the entity replacement
    mjml = '<mjml><mj-body><mj-section data-label="test&nbsp;section"><mj-column><mj-text>Hi</mj-text></mj-column></mj-section></mj-body></mjml>'
    ast = @parser.parse(mjml)
    refute_nil ast
    body = ast.element_children.find { |c| c.tag_name == "mj-body" }
    section = body.element_children.find { |c| c.tag_name == "mj-section" }
    # The attribute value should contain the non-breaking space character
    assert_includes section["data-label"], "test"
    assert_includes section["data-label"], "section"
  end

  def test_greek_letter_entities
    parser = MjmlRb::Parser.new
    content = "&Alpha; &beta; &Omega;"
    converted = parser.send(:replace_html_entities, content)
    assert_equal "&#913; &#946; &#937;", converted
  end

  def test_currency_and_symbol_entities
    parser = MjmlRb::Parser.new
    content = "&euro; &trade; &reg; &bull;"
    converted = parser.send(:replace_html_entities, content)
    assert_equal "&#8364; &#8482; &#174; &#8226;", converted
  end

  def test_entity_replacement_in_realistic_email_template
    mjml = <<~MJML
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text>
                Booking&nbsp;confirmed &mdash; ref&nbsp;#12345
              </mj-text>
              <mj-text>
                &copy;&nbsp;2024 HalalBooking&reg;
              </mj-text>
              <mj-text>
                Price: &euro;199&nbsp;per&nbsp;night &bull; Check-in: 3&nbsp;PM
              </mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    ast = @parser.parse(mjml)
    body = ast.element_children.find { |c| c.tag_name == "mj-body" }
    section = body.element_children.find { |c| c.tag_name == "mj-section" }
    column = section.element_children.find { |c| c.tag_name == "mj-column" }
    texts = column.element_children.select { |c| c.tag_name == "mj-text" }
    assert_equal 3, texts.length
    assert_includes texts[0].content, "Booking"
    assert_includes texts[0].content, "confirmed"
    assert_includes texts[1].content, "2024"
    assert_includes texts[2].content, "199"
  end

  # --- Comments ---

  def test_comments_preserved_when_keep_comments_true
    mjml = <<~MJML
      <mjml><mj-body><!-- my comment --><mj-section><mj-column><mj-text>Hi</mj-text></mj-column></mj-section></mj-body></mjml>
    MJML
    ast = @parser.parse(mjml, keep_comments: true)
    body = ast.element_children.find { |c| c.tag_name == "mj-body" }
    comment = body.children.find { |c| c.comment? }
    refute_nil comment
    assert_includes comment.content, "my comment"
  end

  def test_comments_dropped_when_keep_comments_false
    mjml = <<~MJML
      <mjml><mj-body><!-- my comment --><mj-section><mj-column><mj-text>Hi</mj-text></mj-column></mj-section></mj-body></mjml>
    MJML
    ast = @parser.parse(mjml, keep_comments: false)
    body = ast.element_children.find { |c| c.tag_name == "mj-body" }
    comment = body.children.find { |c| c.comment? }
    assert_nil comment
  end

  # --- Line number annotations ---

  def test_line_numbers_are_annotated
    mjml = "<mjml>\n<mj-body>\n<mj-section>\n</mj-section>\n</mj-body>\n</mjml>"
    ast = @parser.parse(mjml)
    assert_equal 1, ast.line
    body = ast.element_children.find { |c| c.tag_name == "mj-body" }
    assert_equal 2, body.line
  end

  # --- Parse errors ---

  def test_invalid_xml_raises_parse_error
    assert_raises(MjmlRb::Parser::ParseError) do
      @parser.parse("<mjml><unclosed>")
    end
  end

  def test_missing_root_element_raises_parse_error
    assert_raises(MjmlRb::Parser::ParseError) do
      @parser.parse("")
    end
  end

  # --- Preprocessors ---

  def test_preprocessors_are_applied
    preprocessor = ->(xml) { xml.gsub("PLACEHOLDER", "mj-text") }
    mjml = "<mjml><mj-body><mj-section><mj-column><PLACEHOLDER>Hello</PLACEHOLDER></mj-column></mj-section></mj-body></mjml>"
    ast = @parser.parse(mjml, preprocessors: [preprocessor])
    body = ast.element_children.find { |c| c.tag_name == "mj-body" }
    section = body.element_children.find { |c| c.tag_name == "mj-section" }
    column = section.element_children.find { |c| c.tag_name == "mj-column" }
    text = column.element_children.find { |c| c.tag_name == "mj-text" }
    refute_nil text
  end

  def test_multiple_preprocessors_applied_in_order
    p1 = ->(xml) { xml.gsub("AAA", "BBB") }
    p2 = ->(xml) { xml.gsub("BBB", "mj-text") }
    mjml = "<mjml><mj-body><mj-section><mj-column><AAA>Hello</AAA></mj-column></mj-section></mj-body></mjml>"
    ast = @parser.parse(mjml, preprocessors: [p1, p2])
    body = ast.element_children.find { |c| c.tag_name == "mj-body" }
    section = body.element_children.find { |c| c.tag_name == "mj-section" }
    column = section.element_children.find { |c| c.tag_name == "mj-column" }
    text = column.element_children.find { |c| c.tag_name == "mj-text" }
    refute_nil text
  end

  # --- Self-closing ending tags ---

  def test_self_closing_mj_text_does_not_break
    mjml = '<mjml><mj-body><mj-section><mj-column><mj-text /></mj-column></mj-section></mj-body></mjml>'
    ast = @parser.parse(mjml)
    refute_nil ast
  end

  # --- Nested structure ---

  def test_complex_nested_structure
    mjml = <<~MJML
      <mjml>
        <mj-head>
          <mj-title>Test</mj-title>
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text>Hello</mj-text>
              <mj-image src="test.jpg" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    ast = @parser.parse(mjml)
    head = ast.element_children.find { |c| c.tag_name == "mj-head" }
    body = ast.element_children.find { |c| c.tag_name == "mj-body" }
    refute_nil head
    refute_nil body
    title = head.element_children.find { |c| c.tag_name == "mj-title" }
    refute_nil title
  end

  private

  # Walk the AST depth-first and return the first node matching the given tag name.
  def walk_to_first(node, tag_name)
    return node if node.tag_name == tag_name

    node.children.each do |child|
      found = walk_to_first(child, tag_name)
      return found if found
    end
    nil
  end
end
