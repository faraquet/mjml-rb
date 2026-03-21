require "minitest/autorun"
require "nokogiri"

require_relative "../lib/mjml-rb"

class RendererTest < Minitest::Test
  def compile(mjml, **opts)
    MjmlRb::Compiler.new(**opts).compile(mjml)
  end

  # --- Basic document structure ---

  def test_renders_doctype
    result = compile(<<~MJML)
      <mjml><mj-body></mj-body></mjml>
    MJML
    assert_includes result.html, "<!doctype html>"
  end

  def test_renders_html_tag_with_xmlns
    result = compile(<<~MJML)
      <mjml><mj-body></mj-body></mjml>
    MJML
    assert_includes result.html, 'xmlns="http://www.w3.org/1999/xhtml"'
    assert_includes result.html, 'xmlns:v="urn:schemas-microsoft-com:vml"'
    assert_includes result.html, 'xmlns:o="urn:schemas-microsoft-com:office:office"'
  end

  def test_renders_meta_tags
    result = compile(<<~MJML)
      <mjml><mj-body></mj-body></mjml>
    MJML
    assert_includes result.html, 'content="text/html; charset=UTF-8"'
    assert_includes result.html, 'content="width=device-width, initial-scale=1"'
  end

  def test_renders_outlook_document_settings
    result = compile(<<~MJML)
      <mjml><mj-body></mj-body></mjml>
    MJML
    assert_includes result.html, "o:OfficeDocumentSettings"
    assert_includes result.html, "o:AllowPNG"
  end

  def test_renders_outlook_group_fix
    result = compile(<<~MJML)
      <mjml><mj-body></mj-body></mjml>
    MJML
    assert_includes result.html, "mj-outlook-group-fix"
  end

  def test_renders_document_reset_css
    result = compile(<<~MJML)
      <mjml><mj-body></mj-body></mjml>
    MJML
    assert_includes result.html, "#outlook a { padding:0; }"
    assert_includes result.html, "-webkit-text-size-adjust:100%"
  end

  # --- Language attributes ---

  def test_default_lang_is_und
    result = compile(<<~MJML)
      <mjml><mj-body></mj-body></mjml>
    MJML
    assert_includes result.html, 'lang="und"'
  end

  def test_custom_lang_from_mjml_attribute
    result = compile(<<~MJML)
      <mjml lang="en"><mj-body></mj-body></mjml>
    MJML
    assert_includes result.html, 'lang="en"'
  end

  def test_custom_dir_from_mjml_attribute
    result = compile(<<~MJML)
      <mjml dir="rtl"><mj-body></mj-body></mjml>
    MJML
    assert_includes result.html, 'dir="rtl"'
  end

  # --- Title ---

  def test_renders_title_from_mj_title
    result = compile(<<~MJML)
      <mjml>
        <mj-head><mj-title>My Email</mj-title></mj-head>
        <mj-body></mj-body>
      </mjml>
    MJML
    assert_includes result.html, "<title>My Email</title>"
  end

  def test_renders_empty_title_by_default
    result = compile(<<~MJML)
      <mjml><mj-body></mj-body></mjml>
    MJML
    assert_includes result.html, "<title></title>"
  end

  # --- Preview text ---

  def test_renders_preview_text
    result = compile(<<~MJML)
      <mjml>
        <mj-head><mj-preview>Preview text here</mj-preview></mj-head>
        <mj-body></mj-body>
      </mjml>
    MJML
    assert_includes result.html, "Preview text here"
    assert_includes result.html, "display:none"
    assert_includes result.html, "max-height:0px"
  end

  # --- Body background ---

  def test_body_background_color
    result = compile(<<~MJML)
      <mjml>
        <mj-body background-color="#f4f4f4"></mj-body>
      </mjml>
    MJML
    assert_includes result.html, "background-color:#f4f4f4"
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
    assert_includes result.html, "fonts.googleapis.com"
    assert_includes result.html, "Open+Sans"
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
    refute_includes result.html, "fonts.googleapis.com"
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
    assert_includes result.html, "min-width:480px"
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
    assert_includes result.html, "min-width:600px"
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
    assert_includes result.html, "<!-- my comment -->"
  end

  def test_comments_stripped_when_keep_comments_false
    result = compile(<<~MJML, keep_comments: false)
      <mjml>
        <mj-body><!-- my comment -->
          <mj-section><mj-column><mj-text>Hi</mj-text></mj-column></mj-section>
        </mj-body>
      </mjml>
    MJML
    refute_includes result.html, "<!-- my comment -->"
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
    # Minified output should not have multi-space gaps
    refute_match(/>\s{2,}</, result.html)
  end

  def test_beautify_option
    result = compile(<<~MJML, beautify: true)
      <mjml>
        <mj-body>
          <mj-section><mj-column><mj-text>Hello</mj-text></mj-column></mj-section>
        </mj-body>
      </mjml>
    MJML
    # Beautified output has newlines between tags
    assert_includes result.html, ">\n<"
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
    # Adjacent conditionals should be merged (no endif immediately followed by if)
    refute_match(/<!\[endif\]-->\s*<!--\[if mso \| IE\]>/, result.html)
  end
end
