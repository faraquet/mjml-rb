require "minitest/autorun"

require_relative "../lib/mjml-rb"

class SectionTest < Minitest::Test
  FIXTURES_DIR = File.join(__dir__, "fixtures/section")

  def compile(mjml, validation_level: "strict")
    MjmlRb::Compiler.new(validation_level: validation_level).compile(mjml)
  end

  def expected(name)
    File.read(File.join(FIXTURES_DIR, "#{name}.html"))
  end

  def test_section_supports_full_width_mode
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section full-width="full-width" background-color="#112233" css-class="full-section">
            <mj-column>
              <mj-text>Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("full_width_mode"), result.html
  end

  def test_section_accepts_text_padding_in_strict_mode
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section text-padding="8px 12px">
            <mj-column>
              <mj-text>Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("text_padding"), result.html
  end

  def test_section_accepts_string_border_radius_values
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section border-radius="50%/10%">
            <mj-column>
              <mj-text>Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("string_border_radius"), result.html
  end

  def test_section_component_applies_mj_class_background_radius_and_padding
    result = compile(<<~MJML)
      <mjml>
        <mj-head>
          <mj-attributes>
            <mj-class
              name="app-banner"
              background-color="#e0f5f3"
              border-radius="8px"
              padding-left="15px"
              padding-right="15px"
            />
          </mj-attributes>
        </mj-head>
        <mj-body>
          <mj-section mj-class="app-banner" css-class="app-bnr">
            <mj-column>
              <mj-table padding="0">
                <tr><td>Banner</td></tr>
              </mj-table>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("mj_class_attributes"), result.html
  end

  # ── background image tests ────────────────────────────────

  def test_section_background_image_sets_css_shorthand_and_table_attribute
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section
            background-url="https://example.com/bg.jpg"
            background-color="#223344"
            background-size="cover"
            background-repeat="no-repeat"
            background-position="top center"
          >
            <mj-column><mj-text>Hello</mj-text></mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("background_image_css"), result.html
  end

  def test_section_background_image_renders_vml_rect_and_fill
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section
            background-url="https://example.com/bg.jpg"
            background-color="#112233"
            background-size="cover"
            background-repeat="no-repeat"
          >
            <mj-column><mj-text>VML test</mj-text></mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("background_image_vml"), result.html
  end

  def test_section_without_background_url_preserves_original_output
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section background-color="#ff0000">
            <mj-column><mj-text>Plain</mj-text></mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("no_background_url"), result.html
  end

  def test_section_background_position_xy_override
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section
            background-url="https://example.com/bg.jpg"
            background-position="top center"
            background-position-x="right"
            background-position-y="bottom"
          >
            <mj-column><mj-text>Override</mj-text></mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("background_position_xy_override"), result.html
  end

  def test_section_background_repeat_produces_tile_type_in_vml
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section
            background-url="https://example.com/tile.jpg"
            background-repeat="repeat"
            background-size="cover"
          >
            <mj-column><mj-text>Tile</mj-text></mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("background_repeat_tile"), result.html
  end

  def test_section_background_vml_formats_origin_and_position_like_upstream
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section
            background-url="https://example.com/tile.jpg"
            background-repeat="repeat"
            background-size="contain"
            background-position="left top"
          >
            <mj-column><mj-text>Tile</mj-text></mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("vml_origin_position"), result.html
  end

  def test_section_background_auto_size_forces_tile
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section
            background-url="https://example.com/bg.jpg"
            background-repeat="no-repeat"
            background-size="auto"
          >
            <mj-column><mj-text>Auto</mj-text></mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("background_auto_size"), result.html
  end

  # Outlook before table should suffix each css-class word with -outlook.
  def test_section_outlook_before_suffixes_each_css_class
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section css-class="hero banner">
            <mj-column><mj-text>Hello</mj-text></mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("outlook_css_class_suffix"), result.html
  end

  def test_section_background_attributes_pass_strict_validation
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section
            background-url="https://example.com/bg.jpg"
            background-repeat="no-repeat"
            background-size="100%"
            background-position="center center"
            background-position-x="left"
            background-position-y="top"
          >
            <mj-column><mj-text>Valid</mj-text></mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("strict_background_attributes"), result.html
  end

  def test_section_rtl_direction_preserves_source_order_and_emits_upstream_styles
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section direction="rtl">
            <mj-column>
              <mj-text>First</mj-text>
            </mj-column>
            <mj-column>
              <mj-text>Second</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("rtl_direction"), result.html
  end
end
