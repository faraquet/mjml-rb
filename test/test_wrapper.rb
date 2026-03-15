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

  def test_wrapper_background_vml_matches_upstream_outlook_width_and_fill_format
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-wrapper
            background-url="https://example.com/bg.jpg"
            background-color="#cccccc"
            background-repeat="repeat"
            background-size="contain"
            background-position="left top"
          >
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
    assert_includes(result.html, 'origin="0, 0"')
    assert_includes(result.html, 'position="0, 0"')
    assert_includes(result.html, 'width="600" ><table align="center"')
    refute_includes(result.html, 'width="600px" ><table align="center"')
    assert_includes(result.html, 'aspect="atmost"')
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

  def test_wrapper_accepts_full_width_in_strict_mode
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-wrapper full-width="full-width" background-color="#f0f0f0" css-class="hero-wrap">
            <mj-section>
              <mj-column>
                <mj-text>Wrapped</mj-text>
              </mj-column>
            </mj-section>
          </mj-wrapper>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_includes(result.html, 'class="hero-wrap"')
    assert_includes(result.html, 'background:#f0f0f0')
    # Full-width wrapper: background goes on the outer wrapping table
    assert_includes(result.html, 'class="hero-wrap" border="0" cellpadding="0" cellspacing="0" role="presentation" style="width:100%;background:#f0f0f0;background-color:#f0f0f0"')
    assert_includes(result.html, "Wrapped")
  end

  # Each wrapper child section gets its own Outlook <tr><td>, not all in one <tr>.
  def test_wrapper_children_each_get_own_outlook_tr
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-wrapper>
            <mj-section><mj-column><mj-text>A</mj-text></mj-column></mj-section>
            <mj-section><mj-column><mj-text>B</mj-text></mj-column></mj-section>
          </mj-wrapper>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    # After conditional merging, children boundary shows </td></tr><tr><td>
    assert_includes(result.html, "</td></tr><tr><td")
  end

  # Wrapper child Outlook td should carry suffixed css-class.
  def test_wrapper_child_outlook_td_suffixes_css_class
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-wrapper>
            <mj-section css-class="inner hero">
              <mj-column><mj-text>Hello</mj-text></mj-column>
            </mj-section>
          </mj-wrapper>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_includes(result.html, 'class="inner-outlook hero-outlook"')
  end

  # Wrapper with gap should omit bgcolor from Outlook before table on child sections.
  def test_wrapper_gap_omits_bgcolor_from_outlook_before
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-wrapper gap="20px">
            <mj-section background-color="#ff0000">
              <mj-column><mj-text>Red</mj-text></mj-column>
            </mj-section>
            <mj-section background-color="#00ff00">
              <mj-column><mj-text>Green</mj-text></mj-column>
            </mj-section>
          </mj-wrapper>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    # The second section's Outlook before should have padding-top but no bgcolor
    assert_includes(result.html, "padding-top:20px")
    # Second section's Outlook before table: has gap so no bgcolor after width
    assert_includes(result.html, 'style="width:600px;padding-top:20px;" width="600" >')
    # First section (no gap) still has bgcolor in its Outlook before
    assert_includes(result.html, 'bgcolor="#ff0000" >')
  end
end
