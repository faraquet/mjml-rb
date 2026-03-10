require "minitest/autorun"

require_relative "../lib/mjml-rb"

class MJMLHeroTest < Minitest::Test
  def test_hero_component_renders_fixed_height_mode_with_vml_background
    mjml = <<~MJML
      <mjml>
        <mj-body>
          <mj-hero
            mode="fixed-height"
            height="320px"
            background-width="600px"
            background-height="400px"
            background-url="https://example.com/hero.jpg"
            background-color="#223344"
            background-position="top center"
            padding="40px 20px"
            inner-background-color="#ffffff"
            inner-padding="10px 15px"
            css-class="hero-block"
          >
            <mj-text align="center">Hero Title</mj-text>
          </mj-hero>
        </mj-body>
      </mjml>
    MJML

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    assert_empty(result.errors)
    assert_includes(result.html, 'class="hero-block"')
    assert_includes(result.html, 'background="https://example.com/hero.jpg"')
    assert_includes(result.html, 'background-position:top center')
    assert_includes(result.html, 'height="240"')
    assert_includes(result.html, 'height:240px')
    assert_includes(result.html, '<v:image')
    assert_includes(result.html, 'src="https://example.com/hero.jpg"')
    assert_includes(result.html, 'class="mj-hero-content"')
    assert_includes(result.html, 'background-color:#ffffff')
    assert_includes(result.html, 'Hero Title')
  end

  def test_hero_component_renders_fluid_height_mode
    mjml = <<~MJML
      <mjml>
        <mj-body>
          <mj-hero
            mode="fluid-height"
            background-width="800px"
            background-height="400px"
            background-url="https://example.com/fluid.jpg"
            padding="30px 10px"
          >
            <mj-button href="https://example.com">Click</mj-button>
          </mj-hero>
        </mj-body>
      </mjml>
    MJML

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    assert_empty(result.errors)
    assert_includes(result.html, 'padding-bottom:50%')
    assert_includes(result.html, 'mso-padding-bottom-alt:0')
    assert_includes(result.html, 'background="https://example.com/fluid.jpg"')
    assert_includes(result.html, 'Click')
  end
end
