require "minitest/autorun"
require "nokogiri"

require_relative "../lib/mjml-rb"

class WrapperTest < Minitest::Test
  def compile(mjml, validation_level: "strict")
    MjmlRb::Compiler.new(validation_level: validation_level).compile(mjml)
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
