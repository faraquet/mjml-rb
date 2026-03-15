require "minitest/autorun"
require "nokogiri"

require_relative "../lib/mjml-rb"

class SectionTest < Minitest::Test
  def compile(mjml, validation_level: "strict")
    MjmlRb::Compiler.new(validation_level: validation_level).compile(mjml)
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

    document = Nokogiri::HTML(result.html)
    outer_table = document.at_css("table.full-section")
    inner_div = outer_table&.at_css("div")

    refute_nil(outer_table)
    refute_nil(inner_div)
    assert_includes(outer_table["style"].to_s, "width:100%")
    assert_includes(outer_table["style"].to_s, "background:#112233")
    assert_includes(inner_div["style"].to_s, "max-width:600px")
    refute_includes(inner_div["style"].to_s, "background:#112233")
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
    assert_includes(result.html, "Hello")
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
    assert_includes(result.html, "border-radius:50%/10%")
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
    assert_includes(result.html, 'class="app-bnr"')
    assert_includes(result.html, 'style="border-radius:8px;overflow:hidden;margin:0px auto;max-width:600px;background:#e0f5f3;background-color:#e0f5f3"')
    assert_includes(result.html, 'role="presentation" style="border-radius:8px;border-collapse:separate;width:100%;background:#e0f5f3;background-color:#e0f5f3" width="100%"')
    assert_includes(result.html, 'align="center" bgcolor="#e0f5f3"')
    assert_includes(result.html, 'border-radius:8px')
    assert_includes(result.html, 'padding-left:15px')
    assert_includes(result.html, 'padding-right:15px')
    assert_includes(result.html, '<td align="left" style="font-size:0px;font-family:inherit;padding:0;word-break:break-word">')
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
    assert_includes(result.html, "url(&#39;https://example.com/bg.jpg&#39;)")
    assert_includes(result.html, "background-size:cover")
    assert_includes(result.html, "background-repeat:no-repeat")
    assert_includes(result.html, 'background="https://example.com/bg.jpg"')
    assert_includes(result.html, 'style="line-height:0;font-size:0"')
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
    assert_includes(result.html, "<v:rect")
    assert_includes(result.html, "<v:fill")
    assert_includes(result.html, 'src="https://example.com/bg.jpg"')
    assert_includes(result.html, 'type="frame"')
    assert_includes(result.html, "</v:textbox>")
    assert_includes(result.html, "</v:rect>")
    assert_includes(result.html, 'aspect="atleast"')
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
    refute_includes(result.html, "<v:rect")
    refute_includes(result.html, "<v:fill")
    refute_includes(result.html, 'style="line-height:0;font-size:0"')
    assert_includes(result.html, "background:#ff0000")
    assert_includes(result.html, "background-color:#ff0000")
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
    assert_includes(result.html, "background-position:right bottom")
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
    assert_includes(result.html, 'type="tile"')
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
    assert_includes(result.html, 'type="tile"')
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
    assert_includes(result.html, 'class="hero-outlook banner-outlook"')
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

    document = Nokogiri::HTML(result.html)
    section_td = document.at_css("div[aria-roledescription='email'] table tbody tr td[style*='direction:rtl']")
    column_divs = document.css("div.mj-column-per-50")

    refute_nil(section_td)
    assert_includes(section_td["style"].to_s, "direction:rtl")

    assert_equal(2, column_divs.length)
    assert_equal(["First", "Second"], column_divs.map(&:text).map(&:strip))
    column_divs.each do |column_div|
      assert_includes(column_div["style"].to_s, "direction:ltr")
    end
  end
end
