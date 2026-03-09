require "minitest/autorun"

require_relative "../lib/mjml-rb"

class LazyHeadStyleTest < Minitest::Test
  def compile(mjml, **opts)
    MjmlRb::Compiler.new(**opts).compile(mjml)
  end

  # Adapted from upstream: lazy-head-style.test.js
  # The npm test verifies that lazy style functions receive the correct breakpoint.
  # Ruby doesn't have a plugin API, so we verify the same behavior indirectly:
  # mj-breakpoint sets a custom breakpoint and component head styles use it.
  def test_breakpoint_propagates_to_head_styles
    result = compile(<<~MJML)
      <mjml>
        <mj-head>
          <mj-breakpoint width="300px" />
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-image src="https://example.com/img.jpg" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    html = result.html

    # mj-image generates a @media rule using breakpoint - 1
    # With breakpoint 300px, the media query should be max-width:299px
    assert_includes html, "max-width:299px"
    refute_includes html, "max-width:479px", "Should not use default 480px breakpoint"
  end
end
