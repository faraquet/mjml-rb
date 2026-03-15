require "minitest/autorun"
require "nokogiri"

require_relative "../lib/mjml-rb"

class MJMLSpacerTest < Minitest::Test
  def test_spacer_component_renders_with_custom_height_and_css_class
    mjml = <<~MJML
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

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    assert_empty(result.errors)
    assert_includes(result.html, 'class="gap-block"')
    assert_includes(result.html, 'background:#fafafa')
    assert_includes(result.html, 'border-top:2px solid #111111')
    assert_includes(result.html, 'padding:4px 8px')
    assert_includes(result.html, "<div")
    assert_includes(result.html, 'height:48px')
    assert_includes(result.html, 'line-height:48px')
    assert_includes(result.html, 'font-size:0')
    assert_includes(result.html, "&#8202;")
  end

  def test_spacer_component_accepts_upstream_allowed_attributes_in_strict_mode
    mjml = <<~MJML
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

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    assert_empty(result.errors)
  end

  def test_spacer_effective_markup_matches_upstream_layout_contract
    mjml = <<~MJML
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

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    assert_empty(result.errors)

    document = Nokogiri::HTML(result.html)
    spacer_td = document.at_css("td.gap-block")
    spacer_div = spacer_td&.at_css("> div")

    refute_nil(spacer_td)
    refute_nil(spacer_div)
    assert_empty(spacer_td.css("table"), "Spacer should not introduce an extra nested table wrapper")
    assert_includes(spacer_td["style"].to_s, "background:#fafafa")
    assert_includes(spacer_td["style"].to_s, "padding:4px 8px")
    assert_includes(spacer_td["style"].to_s, "word-break:break-word")
    assert_includes(spacer_div["style"].to_s, "height:32px")
    assert_includes(spacer_div["style"].to_s, "line-height:32px")
  end
end
