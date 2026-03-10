require "minitest/autorun"

require_relative "../lib/mjml-rb"

class MJMLBreakpointTest < Minitest::Test
  def test_breakpoint_component_uses_default_desktop_media_query
    mjml = <<~MJML
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column width="50%">
              <mj-text>Left</mj-text>
            </mj-column>
            <mj-column width="50%">
              <mj-text>Right</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    assert_empty(result.errors)
    assert_includes(result.html, "@media only screen and (min-width:480px)")
    assert_includes(result.html, ".mj-column-per-50 { width:50% !important; max-width: 50%; }")
  end

  def test_breakpoint_component_allows_custom_width_in_strict_mode
    mjml = <<~MJML
      <mjml>
        <mj-head>
          <mj-breakpoint width="320px" />
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column width="50%">
              <mj-text>Left</mj-text>
            </mj-column>
            <mj-column width="50%">
              <mj-text>Right</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    assert_empty(result.errors)
    assert_includes(result.html, "@media only screen and (min-width:320px)")
    refute_includes(result.html, "@media only screen and (min-width:480px)")
  end
end
