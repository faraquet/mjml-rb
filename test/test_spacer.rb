require "minitest/autorun"

require_relative "../lib/mjml-rb"

class MJMLSpacerTest < Minitest::Test
  FIXTURES_DIR = File.join(__dir__, "fixtures/spacer")

  def compile(mjml, **opts)
    MjmlRb::Compiler.new(**opts).compile(mjml)
  end

  def expected(name)
    File.read(File.join(FIXTURES_DIR, "#{name}.html"))
  end

  def body_of(html)
    html[/<body[^>]*>(.*)<\/body>/m, 1].strip
  end

  def test_spacer_component_renders_with_custom_height_and_css_class
    result = compile(<<~MJML, validation_level: "strict")
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-spacer
                height="48px"
                css-class="gap-block"
                padding="4px 8px"
                border-top="2px solid #111111"
                container-background-color="#fafafa"
              />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_equal expected("custom_height_and_css_class"), body_of(result.html)
  end

  def test_spacer_component_accepts_upstream_allowed_attributes_in_strict_mode
    result = compile(<<~MJML, validation_level: "strict")
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-spacer
                height="25%"
                border="1px solid #000000"
                border-bottom="2px dashed #ff0000"
                border-left="3px solid #00ff00"
                border-right="4px solid #0000ff"
                border-top="5px solid #111111"
                container-background-color="rgb(250,250,250)"
                padding="1px 2px 3px 4px"
                padding-top="6px"
                padding-right="7%"
                padding-bottom="8px"
                padding-left="9%"
              />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
  end

  def test_spacer_effective_markup_matches_upstream_layout_contract
    result = compile(<<~MJML, validation_level: "strict")
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-spacer
                css-class="gap-block"
                height="32px"
                padding="4px 8px"
                container-background-color="#fafafa"
              />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_equal expected("upstream_layout_contract"), body_of(result.html)
  end
end
