require "minitest/autorun"

require_relative "../lib/mjml-rb"

class RendererTest < Minitest::Test
  FIXTURES_DIR = File.join(__dir__, "fixtures/renderer")

  def compile(mjml, **opts)
    MjmlRb::Compiler.new(**opts).compile(mjml)
  end

  def expected(name)
    File.read(File.join(FIXTURES_DIR, "#{name}.html"))
  end

  # --- Basic document structure ---

  def test_renders_minimal_body
    result = compile(<<~MJML)
      <mjml><mj-body></mj-body></mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, expected("minimal_body")
  end

  # --- Language attributes ---

  def test_custom_lang_from_mjml_attribute
    result = compile(<<~MJML)
      <mjml lang="en"><mj-body></mj-body></mjml>
    MJML
    assert_includes result.html, expected("custom_lang")
  end

  def test_custom_dir_from_mjml_attribute
    result = compile(<<~MJML)
      <mjml dir="rtl"><mj-body></mj-body></mjml>
    MJML
    assert_includes result.html, expected("custom_dir")
  end

  # --- Title ---

  def test_renders_title_from_mj_title
    result = compile(<<~MJML)
      <mjml>
        <mj-head><mj-title>My Email</mj-title></mj-head>
        <mj-body></mj-body>
      </mjml>
    MJML
    assert_includes result.html, expected("title")
  end

  # --- Preview text ---

  def test_renders_preview_text
    result = compile(<<~MJML)
      <mjml>
        <mj-head><mj-preview>Preview text here</mj-preview></mj-head>
        <mj-body></mj-body>
      </mjml>
    MJML
    assert_includes result.html, expected("preview_text")
  end

  # --- Body background ---

  def test_body_background_color
    result = compile(<<~MJML)
      <mjml>
        <mj-body background-color="#f4f4f4"></mj-body>
      </mjml>
    MJML
    assert_includes result.html, expected("body_background_color")
  end

  # --- Font handling ---

  def test_includes_google_font_when_used
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text font-family="Open Sans, sans-serif">Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_includes result.html, expected("google_font")
  end

  def test_does_not_include_unused_fonts
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text font-family="Arial, sans-serif">Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_includes result.html, expected("no_google_font")
  end

  # --- Media queries ---

  def test_media_queries_include_breakpoint
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column></mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_includes result.html, expected("media_queries")
  end

  def test_custom_breakpoint
    result = compile(<<~MJML)
      <mjml>
        <mj-head><mj-breakpoint width="600px" /></mj-head>
        <mj-body>
          <mj-section>
            <mj-column></mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_includes result.html, expected("custom_breakpoint")
  end

  # --- Missing mj-body raises ---

  def test_missing_mj_body_produces_error
    result = compile("<mjml><mj-head></mj-head></mjml>")
    refute result.success?
  end

  # --- Comment rendering ---

  def test_comments_rendered_when_keep_comments_true
    result = compile(<<~MJML, keep_comments: true)
      <mjml>
        <mj-body><!-- my comment -->
          <mj-section><mj-column><mj-text>Hi</mj-text></mj-column></mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_includes result.html, expected("comments_kept")
  end

  def test_comments_stripped_when_keep_comments_false
    result = compile(<<~MJML, keep_comments: false)
      <mjml>
        <mj-body><!-- my comment -->
          <mj-section><mj-column><mj-text>Hi</mj-text></mj-column></mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_includes result.html, expected("comments_stripped")
  end

  # --- Post-processing ---

  def test_minify_option
    result = compile(<<~MJML, minify: true)
      <mjml>
        <mj-body>
          <mj-section><mj-column><mj-text>Hello</mj-text></mj-column></mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_includes result.html, expected("minified")
  end

  def test_beautify_option
    result = compile(<<~MJML, beautify: true)
      <mjml>
        <mj-body>
          <mj-section><mj-column><mj-text>Hello</mj-text></mj-column></mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_includes result.html, expected("beautified")
  end

  # --- Outlook conditional merging ---

  def test_outlook_conditionals_are_merged
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column><mj-text>Col 1</mj-text></mj-column>
            <mj-column><mj-text>Col 2</mj-text></mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_includes result.html, expected("outlook_merged")
  end
end
