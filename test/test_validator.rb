require "minitest/autorun"

require_relative "../lib/mjml-rb"

class ValidatorTest < Minitest::Test
  def validate(mjml)
    result = MjmlRb::Validator.new.validate(mjml, validation_level: "strict")
    result[:errors]
  end

  def test_accepts_column_border_radius_port_case
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column border-radius="50px" inner-border-radius="40px" padding="50px" border="5px solid #000" inner-border="5px solid #666">
              <mj-text>Hello World</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(errors)
  end

  def test_accepts_image_with_required_src
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-image src="https://example.com/logo.png" alt="Logo" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(errors)
  end

  def test_rejects_image_without_src
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-image alt="Logo" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_includes(errors.map { |error| error[:message] }, "Attribute `src` is required for <mj-image>")
  end

  # ── unknown-attribute rejection tests ──────────────────────

  def test_rejects_unknown_attribute_on_mj_button
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-button href="#" fake-attr="x">Click</mj-button>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-button") })
  end

  def test_rejects_unknown_attribute_on_mj_image
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-image src="https://example.com/img.png" fake-attr="x" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-image") })
  end

  def test_rejects_unknown_attribute_on_mj_text
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text fake-attr="x">Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-text") })
  end

  def test_rejects_unknown_attribute_on_mj_divider
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-divider fake-attr="x" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-divider") })
  end

  def test_rejects_unknown_attribute_on_mj_spacer
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-spacer fake-attr="x" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-spacer") })
  end

  def test_rejects_unknown_attribute_on_mj_table
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-table fake-attr="x"><tr><td>A</td></tr></mj-table>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-table") })
  end

  def test_rejects_unknown_attribute_on_mj_raw
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-raw fake-attr="x">raw</mj-raw>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-raw") })
  end

  def test_rejects_unknown_attribute_on_mj_hero
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-hero fake-attr="x">
            <mj-text>Hello</mj-text>
          </mj-hero>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-hero") })
  end

  def test_rejects_invalid_hero_mode_value
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-hero mode="stretch-height">
            <mj-text>Hello</mj-text>
          </mj-hero>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? do |e|
      e[:message].include?("Attribute `mode`") &&
        e[:message].include?("<mj-hero>") &&
        e[:message].include?("enum(fixed-height,fluid-height)")
    end)
  end

  def test_rejects_unknown_attribute_on_mj_column
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column fake-attr="x">
              <mj-text>Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-column") })
  end

  def test_rejects_unknown_attribute_on_mj_section
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section fake-attr="x">
            <mj-column>
              <mj-text>Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-section") })
  end

  def test_rejects_unknown_attribute_on_mj_wrapper
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-wrapper fake-attr="x">
            <mj-section>
              <mj-column>
                <mj-text>Hello</mj-text>
              </mj-column>
            </mj-section>
          </mj-wrapper>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-wrapper") })
  end

  def test_rejects_unknown_attribute_on_mj_group
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-group fake-attr="x">
              <mj-column>
                <mj-text>Hello</mj-text>
              </mj-column>
            </mj-group>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-group") })
  end

  def test_rejects_unknown_attribute_on_mj_body
    errors = validate(<<~MJML)
      <mjml>
        <mj-body fake-attr="x">
          <mj-section>
            <mj-column>
              <mj-text>Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-body") })
  end

  def test_rejects_unknown_attribute_on_mj_carousel
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-carousel fake-attr="x">
                <mj-carousel-image src="https://example.com/1.jpg" />
              </mj-carousel>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-carousel") })
  end

  def test_rejects_unknown_attribute_on_mj_carousel_image
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-carousel>
                <mj-carousel-image src="https://example.com/1.jpg" fake-attr="x" />
              </mj-carousel>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-carousel-image") })
  end

  def test_rejects_unknown_attribute_on_mj_accordion
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-accordion fake-attr="x">
                <mj-accordion-element>
                  <mj-accordion-title>T</mj-accordion-title>
                  <mj-accordion-text>B</mj-accordion-text>
                </mj-accordion-element>
              </mj-accordion>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-accordion") })
  end

  def test_rejects_unknown_attribute_on_mj_navbar
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-navbar fake-attr="x">
                <mj-navbar-link href="/">Home</mj-navbar-link>
              </mj-navbar>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-navbar") })
  end

  def test_rejects_unknown_attribute_on_mj_navbar_link
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-navbar>
                <mj-navbar-link href="/" fake-attr="x">Home</mj-navbar-link>
              </mj-navbar>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-navbar-link") })
  end

  def test_rejects_unknown_attribute_on_mj_breakpoint
    errors = validate(<<~MJML)
      <mjml>
        <mj-head>
          <mj-breakpoint width="480px" fake-attr="x" />
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text>Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-breakpoint") })
  end

  def test_rejects_invalid_mj_style_inline_value
    errors = validate(<<~MJML)
      <mjml>
        <mj-head>
          <mj-style inline="true">.caps { text-transform: uppercase; }</mj-style>
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text>Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? do |e|
      e[:message].include?("Attribute `inline`") &&
        e[:message].include?("<mj-style>") &&
        e[:message].include?("enum(inline)")
    end)
  end

  def test_rejects_invalid_navbar_hamburger_value
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-navbar hamburger="true">
                <mj-navbar-link href="/">Home</mj-navbar-link>
              </mj-navbar>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? do |e|
      e[:message].include?("Attribute `hamburger`") &&
        e[:message].include?("<mj-navbar>") &&
        e[:message].include?("enum(hamburger)")
    end)
  end

  def test_rejects_invalid_text_precise_attribute_values
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text font-size="big" height="tall" letter-spacing="wide" line-height="normal">Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("Attribute `font-size`") && e[:message].include?("<mj-text>") })
    assert(errors.any? { |e| e[:message].include?("Attribute `height`") && e[:message].include?("<mj-text>") })
    assert(errors.any? { |e| e[:message].include?("Attribute `letter-spacing`") && e[:message].include?("<mj-text>") })
    assert(errors.any? { |e| e[:message].include?("Attribute `line-height`") && e[:message].include?("<mj-text>") })
  end

  def test_rejects_invalid_table_precise_attribute_values
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-table cellpadding="10px" cellspacing="wide" font-size="big" line-height="normal" role="article" width="stretch">
                <tr><td>Cell</td></tr>
              </mj-table>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("Attribute `cellpadding`") && e[:message].include?("<mj-table>") })
    assert(errors.any? { |e| e[:message].include?("Attribute `cellspacing`") && e[:message].include?("<mj-table>") })
    assert(errors.any? { |e| e[:message].include?("Attribute `font-size`") && e[:message].include?("<mj-table>") })
    assert(errors.any? { |e| e[:message].include?("Attribute `line-height`") && e[:message].include?("<mj-table>") })
    assert(errors.any? { |e| e[:message].include?("Attribute `role`") && e[:message].include?("<mj-table>") })
    assert(errors.any? { |e| e[:message].include?("Attribute `width`") && e[:message].include?("<mj-table>") })
  end

  def test_accepts_upstream_table_layout_values
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-table table-layout="initial"><tr><td>Initial</td></tr></mj-table>
              <mj-table table-layout="inherit"><tr><td>Inherit</td></tr></mj-table>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(errors)
  end

  def test_accepts_unitless_navbar_line_height_values
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-navbar hamburger="hamburger" ico-line-height="30">
                <mj-navbar-link href="/" line-height="22">Home</mj-navbar-link>
              </mj-navbar>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(errors)
  end

  def test_accepts_negative_letter_spacing_for_upstream_components
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text letter-spacing="-1px">Text</mj-text>
              <mj-button letter-spacing="-0.5em">Button</mj-button>
              <mj-navbar>
                <mj-navbar-link href="/" letter-spacing="-1px">Home</mj-navbar-link>
              </mj-navbar>
              <mj-accordion>
                <mj-accordion-element>
                  <mj-accordion-title>Title</mj-accordion-title>
                  <mj-accordion-text letter-spacing="-1px">Body</mj-accordion-text>
                </mj-accordion-element>
              </mj-accordion>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(errors)
  end

  def test_rejects_unknown_mjml_tag
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-foo />
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("doesn't exist or is not registered") && e[:message].include?("<mj-foo>") })
  end

  def test_allows_html_tags_inside_ending_tag_components
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text><strong>Hello</strong><br />World</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(errors)
  end

  # ── line number metadata tests ──────────────────────

  def test_validation_errors_include_line_numbers
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-image alt="no src" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    src_error = errors.find { |e| e[:message].include?("`src` is required") }
    assert src_error, "Expected a required-src error"
    assert_kind_of Integer, src_error[:line], "Error should have a line number"
    assert src_error[:line] > 0, "Line number should be positive"
    assert_includes src_error[:formatted_message], "line #{src_error[:line]}"
  end

  def test_validation_error_line_number_points_to_correct_element
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text>OK</mj-text>
              <mj-image alt="missing src" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    src_error = errors.find { |e| e[:message].include?("`src` is required") }
    assert src_error
    # mj-image is on line 6 (1-indexed)
    assert_equal 6, src_error[:line]
  end

  def test_ast_nodes_have_line_numbers
    parser = MjmlRb::Parser.new
    ast = parser.parse(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text>Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    # Root mjml node is on line 1
    assert_equal 1, ast.line

    body = ast.element_children.find { |c| c.tag_name == "mj-body" }
    assert body.line, "mj-body should have a line number"
    assert body.line > 1, "mj-body should be after line 1"

    section = body.element_children.first
    assert section.line > body.line, "mj-section should be on a later line than mj-body"
  end

  def test_metadata_attributes_not_leaked_to_component_attributes
    parser = MjmlRb::Parser.new
    ast = parser.parse(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text align="left">Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    # Walk to mj-text
    text_node = ast.element_children
                    .find { |c| c.tag_name == "mj-body" }
                    .element_children.first  # mj-section
                    .element_children.first  # mj-column
                    .element_children.first  # mj-text

    assert_equal "mj-text", text_node.tag_name
    assert_equal "left", text_node.attributes["align"]
    refute text_node.attributes.key?("data-mjml-line"), "data-mjml-line should be stripped from attributes"
    refute text_node.attributes.key?("data-mjml-file"), "data-mjml-file should be stripped from attributes"
    assert text_node.line, "mj-text should have a line number via the line field"
  end
end
