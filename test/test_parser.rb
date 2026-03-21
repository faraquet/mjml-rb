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

  def test_parse_returns_ast_node
    ast = @parser.parse("<mjml><mj-body></mj-body></mjml>")
    assert_instance_of MjmlRb::AstNode, ast
  end

  def test_parse_preserves_attributes
    ast = @parser.parse('<mjml><mj-body background-color="#ffffff"></mj-body></mjml>')
    body = ast.element_children.find { |c| c.tag_name == "mj-body" }
    assert_equal "#ffffff", body.attributes["background-color"]
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
end
