require "minitest/autorun"

require_relative "../lib/mjml-rb"

class MJMLHeroTest < Minitest::Test
  FIXTURES_DIR = File.join(__dir__, "fixtures/hero")

  def compile(mjml)
    MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
  end

  def expected(name)
    File.read(File.join(FIXTURES_DIR, "#{name}.html"))
  end

  def test_hero_component_renders_fixed_height_mode_with_vml_background
    result = compile(<<~MJML)
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

    assert_empty result.errors
    assert_equal expected("fixed_height_mode"), result.html
  end

  def test_hero_component_renders_fluid_height_mode
    result = compile(<<~MJML)
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

    assert_empty result.errors
    assert_equal expected("fluid_height_mode"), result.html
  end

  def test_hero_vml_background_matches_upstream_outlook_wrapper_shape
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-hero
            mode="fixed-height"
            height="320px"
            background-width="600px"
            background-height="400px"
            background-url="https://example.com/hero.jpg"
            background-color="#223344"
            background-position="center center"
            padding="40px 20px"
            inner-background-color="#ffffff"
            inner-padding="10px 15px"
          >
            <mj-text>Hero Title</mj-text>
          </mj-hero>
        </mj-body>
      </mjml>
    MJML

    assert_empty result.errors
    assert_equal expected("vml_background"), result.html
  end

  def test_hero_without_background_url_does_not_emit_vml_image
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-hero mode="fixed-height" height="200px" background-color="#223344">
            <mj-text>No VML image</mj-text>
          </mj-hero>
        </mj-body>
      </mjml>
    MJML

    assert_empty result.errors
    assert_equal expected("no_background_url"), result.html
  end
end
