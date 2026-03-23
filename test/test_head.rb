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
              <mj-text css-class="caps" font-family="Cairo">Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_includes(result.html, "<title>Head Title</title>")
    assert_includes(result.html, "Preview text")
    assert_includes(result.html, 'href="https://fonts.example.test/cairo.css"')
    assert_includes(result.html, '@import url(https://fonts.example.test/cairo.css);')
    assert_includes(result.html, ".caps { text-transform: uppercase; }")
    assert_includes(result.html, '<meta name="x-head" content="1" />')
  end

  def test_custom_font_is_not_emitted_when_unused
    result = compile(<<~MJML, validation_level: "strict")
      <mjml>
        <mj-head>
          <mj-font name="Cairo" href="https://fonts.example.test/cairo.css" />
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text>Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    refute_includes(result.html, 'https://fonts.example.test/cairo.css')
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

  def test_root_level_preview_before_head_is_normalized_and_rendered
    result = compile(<<~MJML, validation_level: "strict")
      <mjml>
        <mj-preview>Preview text before head</mj-preview>
        <mj-head>
          <mj-title>Root Preview Test</mj-title>
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text>Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_includes(result.html, "<title>Root Preview Test</title>")
    assert_includes(result.html, "Preview text before head")
  end

  def test_root_level_head_tags_are_accepted_without_explicit_head
    cases = {
      "mj-attributes" => <<~MJML.chomp,
        <mj-attributes><mj-all font-size="20px" /></mj-attributes>
      MJML
      "mj-breakpoint" => <<~MJML.chomp,
        <mj-breakpoint width="320px" />
      MJML
      "mj-html-attributes" => <<~MJML.chomp,
        <mj-html-attributes><mj-selector path=".target"><mj-html-attribute name="data-x">1</mj-html-attribute></mj-selector></mj-html-attributes>
      MJML
      "mj-font" => <<~MJML.chomp,
        <mj-font name="Cairo" href="https://fonts.example.test/cairo.css" />
      MJML
      "mj-preview" => <<~MJML.chomp,
        <mj-preview>Preview text</mj-preview>
      MJML
      "mj-style" => <<~MJML.chomp,
        <mj-style>.target { text-transform: uppercase; }</mj-style>
      MJML
      "mj-title" => <<~MJML.chomp
        <mj-title>Root Title</mj-title>
      MJML
    }

    cases.each do |tag_name, head_snippet|
      result = compile(<<~MJML, validation_level: "strict")
        <mjml>
          #{head_snippet}
          <mj-body>
            <mj-section>
              <mj-column>
                <mj-text css-class="target" font-family="Cairo">Hello</mj-text>
                <mj-image src="https://example.test/image.png" fluid-on-mobile="true" />
              </mj-column>
            </mj-section>
          </mj-body>
        </mjml>
      MJML

      assert_empty(result.errors, "expected #{tag_name} to be accepted at the root level")
    end
  end
end
