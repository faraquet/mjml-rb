require "minitest/autorun"

require_relative "../lib/mjml-rb"

class TextTest < Minitest::Test
  FIXTURES_DIR = File.join(__dir__, "fixtures/text")

  def compile(mjml, validation_level: "strict")
    MjmlRb::Compiler.new(validation_level: validation_level).compile(mjml)
  end

  def expected(name)
    File.read(File.join(FIXTURES_DIR, "#{name}.html"))
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
    assert_equal expected("background_color"), result.html
  end
end
