require "minitest/autorun"
require "nokogiri"

require_relative "../lib/mjml-rb"

class WrapperTest < Minitest::Test
  def compile(mjml, validation_level: "strict")
    MjmlRb::Compiler.new(validation_level: validation_level).compile(mjml)
  end

  def test_wrapper_and_section_apply_border_radius_overflow_and_separate_border_collapse
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-wrapper border="1px solid red" border-radius="10px">
            <mj-section>
              <mj-column>
                <mj-text font-size="20px" color="#F45E43" font-family="helvetica">Hello World</mj-text>
              </mj-column>
            </mj-section>
          </mj-wrapper>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)

    document = Nokogiri::HTML(result.html)
    wrapper_div = document.at_css("body > div > div")
    wrapper_table = document.at_css("body > div > div > table:first-child")
    wrapper_td = document.at_css("body > div > div > table:first-child > tbody > tr > td")

    refute_nil(wrapper_div)
    refute_nil(wrapper_table)
    refute_nil(wrapper_td)
    assert_includes(wrapper_div["style"].to_s, "border-radius:10px")
    assert_includes(wrapper_div["style"].to_s, "overflow:hidden")
    assert_includes(wrapper_table["style"].to_s, "border-radius:10px")
    assert_includes(wrapper_table["style"].to_s, "border-collapse:separate")
    assert_includes(wrapper_td["style"].to_s, "border-radius:10px")
  end

  def test_wrapper_gap_applies_spacing_between_child_sections
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-wrapper gap="24px">
            <mj-section css-class="first-section">
              <mj-column>
                <mj-text>First</mj-text>
              </mj-column>
            </mj-section>
            <mj-section css-class="second-section">
              <mj-column>
                <mj-text>Second</mj-text>
              </mj-column>
            </mj-section>
          </mj-wrapper>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)

    document = Nokogiri::HTML(result.html)
    first_section = document.at_css("div.first-section")
    second_section = document.at_css("div.second-section")

    refute_nil(first_section)
    refute_nil(second_section)
    refute_includes(first_section["style"].to_s, "margin-top:24px")
    assert_includes(second_section["style"].to_s, "margin-top:24px")
    assert_includes(result.html, 'style="width:600px;padding-top:24px;"')
  end

  def test_wrapper_renders_background_url_styles
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-wrapper background-url="https://example.com/bg.jpg" background-color="#ffffff" background-size="cover" background-repeat="no-repeat">
            <mj-section>
              <mj-column>
                <mj-text>Hello</mj-text>
              </mj-column>
            </mj-section>
          </mj-wrapper>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)

    document = Nokogiri::HTML(result.html)
    wrapper_div = document.at_css("body > div > div")
    wrapper_table = wrapper_div.at_css("table")

    refute_nil(wrapper_div)
    refute_nil(wrapper_table)

    # div and table should have background-url styles
    assert_includes(wrapper_div["style"].to_s, "url('https://example.com/bg.jpg')")
    assert_includes(wrapper_div["style"].to_s, "background-size:cover")
    assert_includes(wrapper_div["style"].to_s, "background-repeat:no-repeat")
    assert_includes(wrapper_table["style"].to_s, "url('https://example.com/bg.jpg')")

    # table should have background HTML attribute
    assert_equal("https://example.com/bg.jpg", wrapper_table["background"])

    # innerDiv should be present (line-height:0;font-size:0)
    inner_div = wrapper_div.at_css("table tbody tr td > div")
    refute_nil(inner_div, "innerDiv should be present when background-url is set")
    assert_includes(inner_div["style"].to_s, "line-height:0")
    assert_includes(inner_div["style"].to_s, "font-size:0")
  end

  def test_wrapper_renders_vml_for_background_url
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-wrapper background-url="https://example.com/bg.jpg" background-color="#cccccc">
            <mj-section>
              <mj-column>
                <mj-text>Hello</mj-text>
              </mj-column>
            </mj-section>
          </mj-wrapper>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)

    # VML rect and fill should be present
    assert_includes(result.html, "v:rect")
    assert_includes(result.html, "v:fill")
    assert_includes(result.html, "v:textbox")
    assert_includes(result.html, 'src="https://example.com/bg.jpg"')
    assert_includes(result.html, 'color="#cccccc"')
  end

  def test_wrapper_full_width_with_background_url
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-wrapper full-width="full-width" background-url="https://example.com/bg.jpg" background-color="#ffffff" css-class="hero">
            <mj-section>
              <mj-column>
                <mj-text>Hello</mj-text>
              </mj-column>
            </mj-section>
          </mj-wrapper>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)

    document = Nokogiri::HTML(result.html)

    # Outer table should have background styles and css-class
    outer_table = document.at_css("body > div > table")
    refute_nil(outer_table, "full-width wrapper should have outer table")
    assert_equal("hero", outer_table["class"])
    assert_equal("https://example.com/bg.jpg", outer_table["background"])
    assert_includes(outer_table["style"].to_s, "url('https://example.com/bg.jpg')")

    # Inner div should NOT have background styles (full-width puts them on outer table)
    inner_div = outer_table.at_css("td > div") || outer_table.at_css("div")
    # The inner div's style should not contain background-url
    # (background goes on the outer table for full-width)
    if inner_div
      refute_includes(inner_div["style"].to_s, "background-url")
    end

    # VML should use mso-width-percent:1000 for full-width
    assert_includes(result.html, "mso-width-percent:1000")
  end

  def test_wrapper_without_background_url_has_no_vml_or_inner_div
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-wrapper background-color="#f0f0f0">
            <mj-section>
              <mj-column>
                <mj-text>Hello</mj-text>
              </mj-column>
            </mj-section>
          </mj-wrapper>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)

    # No VML when there's no background-url
    refute_includes(result.html, "v:rect")
    refute_includes(result.html, "v:fill")

    document = Nokogiri::HTML(result.html)
    wrapper_div = document.at_css("body > div > div")
    refute_nil(wrapper_div)

    # background-color should still be applied
    assert_includes(wrapper_div["style"].to_s, "background:#f0f0f0")

    # No innerDiv (line-height:0;font-size:0) when there's no background-url
    refute_includes(result.html, "line-height:0;font-size:0")
  end
end
