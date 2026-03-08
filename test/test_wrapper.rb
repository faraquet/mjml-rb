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
end
