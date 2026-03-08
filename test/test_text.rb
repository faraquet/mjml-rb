require "minitest/autorun"
require "nokogiri"

require_relative "../lib/mjml-rb"

class TextTest < Minitest::Test
  def compile(mjml, validation_level: "strict")
    MjmlRb::Compiler.new(validation_level: validation_level).compile(mjml)
  end

  def test_text_supports_background_color_in_strict_mode
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text background-color="#ffeecc">Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)

    document = Nokogiri::HTML(result.html)
    text_node = document.at_xpath("//div[text()='Hello']")

    refute_nil(text_node)
    assert_equal("#ffeecc", extract_style_value(text_node["style"], "background-color"))
  end

  private

  def extract_style_value(style, property)
    styles = style.to_s.split(";").map(&:strip).reject(&:empty?)
    entry = styles.find { |item| item.start_with?("#{property}:") }
    entry&.split(":", 2)&.last&.strip
  end
end
