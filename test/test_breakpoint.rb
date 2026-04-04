require "minitest/autorun"

require_relative "../lib/mjml-rb"

class MJMLBreakpointTest < Minitest::Test
  FIXTURES_DIR = File.join(__dir__, "fixtures/breakpoint")

  def compile(mjml)
    MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
  end

  def expected(name)
    File.read(File.join(FIXTURES_DIR, "#{name}.html"))
  end

  def test_breakpoint_component_uses_default_desktop_media_query
    result = compile(<<~MJML)
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

    assert_empty(result.errors)
    assert_includes result.html, expected("default_desktop_media_query")
  end

  def test_breakpoint_component_allows_custom_width_in_strict_mode
    result = compile(<<~MJML)
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

    assert_empty(result.errors)
    assert_includes result.html, expected("custom_width")
  end
end
