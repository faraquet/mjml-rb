require "minitest/autorun"
require "nokogiri"

require_relative "../lib/mjml-rb"

class AllTest < Minitest::Test
  def compile(mjml, validation_level: "soft")
    MjmlRb::Compiler.new(validation_level: validation_level).compile(mjml)
  end

  def test_mj_all_matches_global_default_precedence_from_mjml
    result = compile(<<~MJML, validation_level: "strict")
      <mjml>
        <mj-head>
          <mj-attributes>
            <mj-all font-family="Arial" color="#111111" padding="0" />
            <mj-text color="#222222" font-size="20px" />
          </mj-attributes>
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text color="#333333">Hello</mj-text>
              <mj-button href="https://example.test">Button</mj-button>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)

    document = Nokogiri::HTML(result.html)
    text_node = document.at_xpath("//div[text()='Hello']")
    text_cell = text_node&.ancestors("td")&.first
    button_node = document.at_xpath("//a[text()='Button']")

    refute_nil(text_node)
    refute_nil(text_cell)
    refute_nil(button_node)

    assert_equal("Arial", extract_style_value(text_node["style"], "font-family"))
    assert_equal("20px", extract_style_value(text_node["style"], "font-size"))
    assert_equal("#333333", extract_style_value(text_node["style"], "color"))
    assert_equal("0", extract_style_value(text_cell["style"], "padding"))

    assert_equal("Arial", extract_style_value(button_node["style"], "font-family"))
    assert_equal("#111111", extract_style_value(button_node["style"], "color"))
  end

  private

  def extract_style_value(style, property)
    styles = style.to_s.split(";").map(&:strip).reject(&:empty?)
    entry = styles.find { |item| item.start_with?("#{property}:") }
    entry&.split(":", 2)&.last&.strip
  end
end
