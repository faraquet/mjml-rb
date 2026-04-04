require "minitest/autorun"

require_relative "../lib/mjml-rb"

class HtmlCommentsTest < Minitest::Test
  FIXTURES_DIR = File.join(__dir__, "fixtures/html_comments")

  def compile(mjml, **opts)
    MjmlRb::Compiler.new(**opts).compile(mjml)
  end

  def expected(name)
    File.read(File.join(FIXTURES_DIR, "#{name}.html"))
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

    assert_includes result.html, expected("preserve_whitespace")
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
    assert_includes result.html, expected("comments_preserved")
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
    assert_includes result.html, expected("comments_removed")
  end
end
