require "minitest/autorun"

require_relative "../lib/mjml-rb"

class MJMLBodyTest < Minitest::Test
  def test_body_component_renders_attributes_and_context
    body = <<~MJML
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

    result = MjmlRb::Compiler.new.compile(body)
    assert_empty(result.errors)
    assert_includes(result.html, '<html lang="ar" dir="rtl" xmlns="http://www.w3.org/1999/xhtml"')
    assert_includes(result.html, '<body style="word-spacing:normal;background-color:#f5f5f5">')
    assert_includes(result.html, 'aria-label="Body Title"')
    assert_includes(result.html, 'aria-roledescription="email"')
    assert_includes(result.html, 'class="body-class"')
    assert_includes(result.html, 'role="article"')
    assert_includes(result.html, 'style="background-color:#f5f5f5"')
    assert_includes(result.html, 'max-width:700px')
  end

  def test_body_component_uses_default_width
    body = <<~MJML
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

    result = MjmlRb::Compiler.new.compile(body)
    assert_empty(result.errors)

    assert_includes(result.html, 'max-width:600px')
    assert_includes(result.html, 'mj-column-per-100')
    assert_includes(result.html, 'Default body width')
  end
end
