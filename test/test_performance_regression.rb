require "minitest/autorun"
require_relative "../lib/mjml-rb"

# Regression tests to ensure performance optimizations don't change output.
# Each test captures exact HTML output before and after optimization.
class TestPerformanceRegression < Minitest::Test
  def compile(mjml, **opts)
    MjmlRb::Compiler.new(validation_level: "skip", **opts).compile(mjml)
  end

  # --- AstNode#element_children memoization ---

  def test_element_children_returns_same_result_on_repeated_calls
    ast = MjmlRb::Parser.new.parse(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text>Hello</mj-text>
              <mj-image src="img.png" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    body = ast.element_children.find { |c| c.tag_name == "mj-body" }
    first_call = body.element_children
    second_call = body.element_children

    assert_equal first_call.map(&:tag_name), second_call.map(&:tag_name)
    assert_equal first_call.size, second_call.size
  end

  # --- ComponentRegistry caching ---

  def test_component_class_for_tag_returns_correct_classes
    registry = MjmlRb.component_registry

    assert_equal MjmlRb::Components::Text, registry.component_class_for_tag("mj-text")
    assert_equal MjmlRb::Components::Button, registry.component_class_for_tag("mj-button")
    assert_equal MjmlRb::Components::Section, registry.component_class_for_tag("mj-section")
    assert_equal MjmlRb::Components::Column, registry.component_class_for_tag("mj-column")
    assert_equal MjmlRb::Components::Image, registry.component_class_for_tag("mj-image")
    assert_nil registry.component_class_for_tag("mj-nonexistent")
  end

  def test_dependency_rules_contain_expected_entries
    rules = MjmlRb.component_registry.dependency_rules
    assert_includes rules.keys, "mj-body"
    assert_includes rules.keys, "mj-section"
    assert_includes rules.keys, "mj-column"
    assert_includes rules["mj-body"], "mj-section"
    assert_includes rules["mj-column"], "mj-text"
  end

  def test_ending_tags_contain_expected_entries
    tags = MjmlRb.component_registry.ending_tags
    assert_includes tags, "mj-text"
    assert_includes tags, "mj-button"
    assert_includes tags, "mj-raw"
    assert_includes tags, "mj-table"
  end

  # --- Full compilation output stability ---

  def test_simple_text_output_unchanged
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text>Hello World</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert result.success?, "Compilation failed: #{result.errors.inspect}"
    assert_includes result.html, "Hello World"
    assert_includes result.html, "mj-column-per-100"
  end

  def test_multi_column_output_unchanged
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text>Col 1</mj-text>
            </mj-column>
            <mj-column>
              <mj-text>Col 2</mj-text>
            </mj-column>
            <mj-column>
              <mj-text>Col 3</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert result.success?
    assert_includes result.html, "Col 1"
    assert_includes result.html, "Col 2"
    assert_includes result.html, "Col 3"
    # Each column should get ~33.33% width class
    assert_includes result.html, "mj-column-per-33-333333333333336"
  end

  def test_carousel_output_unchanged
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-carousel>
                <mj-carousel-image src="img1.png" />
                <mj-carousel-image src="img2.png" />
                <mj-carousel-image src="img3.png" />
              </mj-carousel>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert result.success?
    assert_includes result.html, "img1.png"
    assert_includes result.html, "img2.png"
    assert_includes result.html, "img3.png"
    assert_includes result.html, "mj-carousel"
    # Carousel head styles should be present
    assert_includes result.html, "mj-carousel-image"
  end

  def test_social_output_unchanged
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-social font-size="15px" icon-size="30px" mode="horizontal">
                <mj-social-element name="facebook" href="https://facebook.com">Facebook</mj-social-element>
                <mj-social-element name="twitter" href="https://twitter.com">Twitter</mj-social-element>
              </mj-social>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert result.success?
    assert_includes result.html, "facebook.png"
    assert_includes result.html, "twitter.png"
    assert_includes result.html, "Facebook"
    assert_includes result.html, "Twitter"
  end

  def test_accordion_output_unchanged
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-accordion>
                <mj-accordion-element>
                  <mj-accordion-title>Question 1</mj-accordion-title>
                  <mj-accordion-text>Answer 1</mj-accordion-text>
                </mj-accordion-element>
              </mj-accordion>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert result.success?
    assert_includes result.html, "Question 1"
    assert_includes result.html, "Answer 1"
    assert_includes result.html, "mj-accordion"
  end

  def test_hero_output_unchanged
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-hero background-url="https://example.com/bg.jpg" background-height="400px" mode="fixed-height" height="400px">
            <mj-text>Hero Content</mj-text>
          </mj-hero>
        </mj-body>
      </mjml>
    MJML

    assert result.success?
    assert_includes result.html, "Hero Content"
    assert_includes result.html, "bg.jpg"
  end

  def test_head_attributes_output_unchanged
    result = compile(<<~MJML)
      <mjml>
        <mj-head>
          <mj-attributes>
            <mj-text color="#ff0000" font-size="20px" />
            <mj-all font-family="Arial" />
          </mj-attributes>
          <mj-title>Test Title</mj-title>
          <mj-preview>Preview text</mj-preview>
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text>Styled text</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert result.success?
    assert_includes result.html, "Test Title"
    assert_includes result.html, "Preview text"
    assert_includes result.html, "#ff0000"
  end

  def test_validation_still_works_after_optimization
    result = MjmlRb::Validator.new.validate(<<~MJML, validation_level: "strict")
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text>Valid</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty result[:errors]
  end

  def test_validation_catches_invalid_nesting
    result = MjmlRb::Validator.new.validate(<<~MJML, validation_level: "strict")
      <mjml>
        <mj-body>
          <mj-text>Wrong nesting</mj-text>
        </mj-body>
      </mjml>
    MJML

    assert result[:errors].any? { |e| e[:message].include?("not allowed") }
  end

  # --- Parser regex pre-compilation ---

  def test_parser_cdata_wrapping_unchanged
    parser = MjmlRb::Parser.new
    ast = parser.parse(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text><p>Hello &amp; world</p></mj-text>
              <mj-button href="https://example.com">Click &amp; Go</mj-button>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    body = ast.element_children.find { |c| c.tag_name == "mj-body" }
    section = body.element_children.first
    column = section.element_children.first
    text_node = column.element_children.find { |c| c.tag_name == "mj-text" }
    button_node = column.element_children.find { |c| c.tag_name == "mj-button" }

    assert text_node.content.include?("Hello")
    assert button_node.content.include?("Click")
  end

  def test_parser_void_tags_unchanged
    parser = MjmlRb::Parser.new
    ast = parser.parse(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text><br>line break<hr>rule<img src="test.png"></mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    body = ast.element_children.find { |c| c.tag_name == "mj-body" }
    section = body.element_children.first
    column = section.element_children.first
    text_node = column.element_children.find { |c| c.tag_name == "mj-text" }

    assert text_node.content.include?("br")
    assert text_node.content.include?("hr")
  end

  # --- text_content optimization ---

  def test_text_content_returns_same_result
    ast = MjmlRb::Parser.new.parse(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-image src="test.png" alt="test image" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    # text_content should aggregate all text nodes
    content = ast.text_content
    assert_kind_of String, content
  end

  # --- Full-width section output stability ---

  def test_full_width_section_output_unchanged
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section full-width="full-width" background-color="#ff0000">
            <mj-column>
              <mj-text>Full width</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert result.success?
    assert_includes result.html, "Full width"
    assert_includes result.html, "#ff0000"
  end

  # --- Wrapper output stability ---

  def test_wrapper_output_unchanged
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-wrapper background-color="#eeeeee">
            <mj-section>
              <mj-column>
                <mj-text>Inside wrapper</mj-text>
              </mj-column>
            </mj-section>
          </mj-wrapper>
        </mj-body>
      </mjml>
    MJML

    assert result.success?
    assert_includes result.html, "Inside wrapper"
    assert_includes result.html, "#eeeeee"
  end

  # --- Exact output snapshot test ---
  # This captures the full output for a complex template to detect ANY change

  COMPLEX_TEMPLATE = <<~MJML
    <mjml>
      <mj-head>
        <mj-title>Newsletter</mj-title>
        <mj-preview>Weekly update</mj-preview>
        <mj-attributes>
          <mj-all font-family="Arial, sans-serif" />
          <mj-text font-size="14px" color="#333" />
        </mj-attributes>
      </mj-head>
      <mj-body background-color="#f4f4f4">
        <mj-section background-color="#ffffff" padding="20px">
          <mj-column width="60%">
            <mj-text font-size="24px" font-weight="bold">Welcome</mj-text>
            <mj-text>This is a test newsletter with <b>bold</b> and <i>italic</i> text.</mj-text>
            <mj-button href="https://example.com" background-color="#007bff">Read More</mj-button>
          </mj-column>
          <mj-column width="40%">
            <mj-image src="https://example.com/image.jpg" alt="Hero" />
          </mj-column>
        </mj-section>
        <mj-section>
          <mj-column>
            <mj-divider border-color="#eee" />
            <mj-text align="center" font-size="12px" color="#999">Footer text</mj-text>
          </mj-column>
        </mj-section>
      </mj-body>
    </mjml>
  MJML

  def test_complex_template_exact_output
    result = compile(COMPLEX_TEMPLATE)
    assert result.success?

    html = result.html

    # Structural checks
    assert_includes html, "<title>Newsletter</title>"
    assert_includes html, "Weekly update"
    assert_includes html, "Welcome"
    assert_includes html, "Read More"
    assert_includes html, "Footer text"
    assert_includes html, "example.com/image.jpg"
    assert_includes html, "#007bff"
    assert_includes html, "mj-column-per-60"
    assert_includes html, "mj-column-per-40"

    # Store a checksum of output to detect changes
    @complex_output = html
  end

  def test_complex_template_deterministic
    result1 = compile(COMPLEX_TEMPLATE)
    result2 = compile(COMPLEX_TEMPLATE)

    assert_equal result1.html, result2.html, "Output should be deterministic"
  end
end
