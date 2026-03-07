require "minitest/autorun"

require_relative "../lib/mjml-rb"

class HeadTest < Minitest::Test
  def compile(mjml, validation_level: "soft")
    MjmlRb::Compiler.new(validation_level: validation_level).compile(mjml)
  end

  def test_head_component_handles_core_head_children
    result = compile(<<~MJML, validation_level: "strict")
      <mjml lang="ar">
        <mj-head>
          <mj-title>Head Title</mj-title>
          <mj-preview>Preview text</mj-preview>
          <mj-font name="Cairo" href="https://fonts.example.test/cairo.css" />
          <mj-style>.caps { text-transform: uppercase; }</mj-style>
          <mj-raw><meta name="x-head" content="1" /></mj-raw>
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text css-class="caps">Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_includes(result.html, "<title>Head Title</title>")
    assert_includes(result.html, "Preview text")
    assert_includes(result.html, 'href="https://fonts.example.test/cairo.css"')
    assert_includes(result.html, ".caps { text-transform: uppercase; }")
    assert_includes(result.html, '<meta name="x-head" content="1" />')
  end

  def test_image_mobile_head_style_uses_active_breakpoint
    result = compile(<<~MJML, validation_level: "strict")
      <mjml>
        <mj-head>
          <mj-breakpoint width="320px" />
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-image src="https://example.test/image.png" fluid-on-mobile="true" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_includes(result.html, "@media only screen and (max-width:319px)")
  end
end
