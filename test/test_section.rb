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
end
