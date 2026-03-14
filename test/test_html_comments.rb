require "minitest/autorun"

require_relative "../lib/mjml-rb"

class HtmlCommentsTest < Minitest::Test
  def compile(mjml, **opts)
    MjmlRb::Compiler.new(**opts).compile(mjml)
  end

  # Ported from upstream: html-comments.test.js
  def test_html_comments_preserve_whitespace
    result = compile(<<~MJML, keep_comments: true)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text>
              <p>View source to see comments below</p>
              <!-- comment with standard spaces -->
              <br>
              <!--comment without spaces-->
              <br>
              <!--     comment with 5 spaces     -->
              </mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    html = result.html

    assert_includes html, "<!-- comment with standard spaces -->"
    assert_includes html, "<!--comment without spaces-->"
    assert_includes html, "<!--     comment with 5 spaces     -->"
  end

  def test_html_comments_outside_ending_tags_are_preserved_when_enabled
    result = compile(<<~MJML, keep_comments: true)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <!-- column comment -->
              <mj-text>Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty result.errors
    assert_includes result.html, "<!-- column comment -->"
    assert_includes result.html, "Hello"
  end

  def test_html_comments_are_removed_when_disabled
    result = compile(<<~MJML, keep_comments: false)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <!-- hidden comment -->
              <mj-text>Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty result.errors
    refute_includes result.html, "<!-- hidden comment -->"
    assert_includes result.html, "Hello"
  end
end
