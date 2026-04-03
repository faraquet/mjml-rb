require "minitest/autorun"

require_relative "../lib/mjml-rb"

class MJMLBodyTest < Minitest::Test
  FIXTURES_DIR = File.join(__dir__, "fixtures/body")

  def compile(mjml)
    MjmlRb::Compiler.new.compile(mjml)
  end

  def expected(name)
    File.read(File.join(FIXTURES_DIR, "#{name}.html"))
  end

  def test_body_component_renders_attributes_and_context
    result = compile(<<~MJML)
      <mjml lang="ar" dir="rtl">
        <mj-head>
          <mj-title>Body Title</mj-title>
        </mj-head>
        <mj-body width="700px" background-color="#f5f5f5" css-class="body-class">
          <mj-section>
            <mj-column>
              <mj-text>Body Test</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("attributes_and_context"), result.html
  end

  def test_body_component_uses_default_width
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text>Default body width</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("default_width"), result.html
  end
end
