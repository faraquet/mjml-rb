require "minitest/autorun"
require "tmpdir"
require "stringio"

require_relative "../lib/mjml-rb"

class MJMLCompilerTest < Minitest::Test
  SAMPLE = <<~MJML
    <mjml>
      <mj-body>
        <mj-section>
          <mj-column>
            <mj-text>Hello Ruby</mj-text>
          </mj-column>
        </mj-section>
      </mj-body>
    </mjml>
  MJML

  def test_mjml2html_returns_html
    result = MjmlRb.mjml2html(SAMPLE)
    assert_empty(result[:errors])
    assert_includes(result[:html], "Hello Ruby")
  end

  def test_strict_validation_rejects_invalid_document
    compiler = MjmlRb::Compiler.new(validation_level: "strict")
    result = compiler.compile("<html><body>invalid</body></html>")
    refute_empty(result.errors)
  end

  def test_dependency_validation_rejects_invalid_child
    invalid = <<~MJML
      <mjml>
        <mj-body>
          <mj-text>invalid position</mj-text>
        </mj-body>
      </mjml>
    MJML

    compiler = MjmlRb::Compiler.new(validation_level: "soft")
    result = compiler.compile(invalid)
    refute_empty(result.errors)
    assert_match(/not allowed inside <mj-body>/, result.errors.first[:message])
  end

  def test_include_expansion
    Dir.mktmpdir do |dir|
      partial = File.join(dir, "partial.mjml")
      main = File.join(dir, "main.mjml")
      File.write(partial, "<mj-text>From include</mj-text>")
      File.write(main, <<~MJML)
        <mjml>
          <mj-body>
            <mj-section>
              <mj-column>
                <mj-include path="./partial.mjml" />
              </mj-column>
            </mj-section>
          </mj-body>
        </mjml>
      MJML

      compiler = MjmlRb::Compiler.new(actual_path: main, file_path: dir)
      result = compiler.compile(File.read(main))
      assert_empty(result.errors)
      assert_includes(result.html, "From include")
    end
  end

  def test_include_expansion_tolerates_html_void_tags_in_mjml_include
    Dir.mktmpdir do |dir|
      partial = File.join(dir, "partial.mjml")
      main = File.join(dir, "main.mjml")
      File.write(partial, "<mj-text>Line 1<br><strong>Line 2</strong></mj-text>")
      File.write(main, <<~MJML)
        <mjml>
          <mj-body>
            <mj-section>
              <mj-column>
                <mj-include path="./partial.mjml" />
              </mj-column>
            </mj-section>
          </mj-body>
        </mjml>
      MJML

      compiler = MjmlRb::Compiler.new(actual_path: main, file_path: dir)
      result = compiler.compile(File.read(main))
      assert_empty(result.errors)
      assert_includes(result.html, "Line 1")
      assert_includes(result.html, "<strong>Line 2</strong>")
    end
  end

  def test_include_expansion_tolerates_html_type_with_void_tags
    Dir.mktmpdir do |dir|
      partial = File.join(dir, "partial.html")
      main = File.join(dir, "main.mjml")
      File.write(partial, "<p>Line 1<br><strong>Line 2</strong></p>")
      File.write(main, <<~MJML)
        <mjml>
          <mj-body>
            <mj-section>
              <mj-column>
                <mj-include path="./partial.html" type="html" />
              </mj-column>
            </mj-section>
          </mj-body>
        </mjml>
      MJML

      compiler = MjmlRb::Compiler.new(actual_path: main, file_path: dir)
      result = compiler.compile(File.read(main))
      assert_empty(result.errors)
      assert_includes(result.html, "<p>Line 1<br><strong>Line 2</strong></p>")
    end
  end

  def test_include_expansion_tolerates_html_void_tags_in_strict_mode
    Dir.mktmpdir do |dir|
      partial = File.join(dir, "partial.mjml")
      main = File.join(dir, "main.mjml")
      File.write(partial, "<mj-text>Line 1<br><strong>Line 2</strong></mj-text>")
      File.write(main, <<~MJML)
        <mjml>
          <mj-body>
            <mj-section>
              <mj-column>
                <mj-include path="./partial.mjml" />
              </mj-column>
            </mj-section>
          </mj-body>
        </mjml>
      MJML

      compiler = MjmlRb::Compiler.new(actual_path: main, file_path: dir, validation_level: "strict")
      result = compiler.compile(File.read(main))
      assert_empty(result.errors)
      assert_includes(result.html, "<br />")
      assert_includes(result.html, "<strong>Line 2</strong>")
    end
  end

  def test_direct_inline_html_void_tags_in_mj_text_strict_mode
    mjml = <<~MJML
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text>Hello<br><strong>World</strong></mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    assert_empty(result.errors)
    assert_includes(result.html, "<br />")
    assert_includes(result.html, "<strong>World</strong>")
  end

  def test_mj_raw_allows_html_children_in_strict_mode
    mjml = <<~MJML
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-raw><meta name="x-test" content="1" /><style>.x{color:red;}</style></mj-raw>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    assert_empty(result.errors)
    assert_includes(result.html, '<meta name="x-test" content="1" />')
    assert_includes(result.html, "<style>.x{color:red;}</style>")
  end

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

  def test_mj_table_allows_tr_children_in_strict_mode
    mjml = <<~MJML
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-table>
                <tr><td>A</td></tr>
                <tr><td>B</td></tr>
              </mj-table>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    assert_empty(result.errors)
    assert_includes(result.html, "<tr><td style=\"font-family: inherit\">A</td></tr>")
    assert_includes(result.html, "<tr><td style=\"font-family: inherit\">B</td></tr>")
  end

  def test_mj_table_normalizes_raw_html_table_children
    mjml = <<~MJML
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-table padding="0" css-class="padding--none--this">
                <tr>
                  <td style="direction: ltr">
                    <table>
                      <tr>
                        <td style="width: 60px; padding-right: 10px;">A</td>
                        <td style="vertical-align: middle; font-size: 15px;">B</td>
                      </tr>
                    </table>
                  </td>
                  <td style="text-align: right">C</td>
                </tr>
              </mj-table>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    assert_empty(result.errors)
    assert_includes(result.html, 'class="padding--none--this"')
    assert_includes(result.html, 'font-family:inherit')
    assert_includes(result.html, '<table width="100%"')
    assert_includes(result.html, 'style="font-family: inherit; width: 100%"')
    assert_includes(result.html, '<td style="width: 60px; padding-right: 10px; font-family: inherit" width="60">A</td>')
    assert_includes(result.html, '<td style="vertical-align: middle; font-size: 15px; font-family: inherit" valign="middle">B</td>')
    assert_includes(result.html, '<td style="text-align: right; font-family: inherit" align="right">C</td>')
  end

  def test_button_component_renders_with_href
    mjml = <<~MJML
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-button href="https://example.com">Click me</mj-button>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    result = MjmlRb::Compiler.new.compile(mjml)
    assert_empty(result.errors)
    # Outer wrapper
    assert_includes(result.html, 'align="center"')
    assert_includes(result.html, 'word-break:break-word')
    # Inner button table
    assert_includes(result.html, 'border-collapse:separate')
    assert_includes(result.html, 'line-height:100%')
    # Inner td with bgcolor
    assert_includes(result.html, 'bgcolor="#414141"')
    assert_includes(result.html, 'border-radius:3px')
    assert_includes(result.html, 'cursor:auto')
    assert_includes(result.html, 'mso-padding-alt:10px 25px')
    # Link
    assert_includes(result.html, 'href="https://example.com"')
    assert_includes(result.html, 'target="_blank"')
    assert_includes(result.html, 'display:inline-block')
    assert_includes(result.html, 'mso-padding-alt:0px')
    assert_includes(result.html, 'Click me')
  end

  def test_button_component_renders_without_href_as_p_tag
    mjml = <<~MJML
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-button>No link</mj-button>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    result = MjmlRb::Compiler.new.compile(mjml)
    assert_empty(result.errors)
    assert_includes(result.html, '<p ')
    refute_includes(result.html, '<a ')
    assert_includes(result.html, 'No link')
  end

  def test_button_component_respects_custom_attributes
    mjml = <<~MJML
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-button href="https://example.com"
                background-color="#ff0000"
                color="#000000"
                font-size="16px"
                border-radius="8px"
                inner-padding="15px 30px"
                padding="20px 30px"
                target="_self">Buy Now</mj-button>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    result = MjmlRb::Compiler.new.compile(mjml)
    assert_empty(result.errors)
    assert_includes(result.html, 'bgcolor="#ff0000"')
    assert_includes(result.html, 'background:#ff0000')
    assert_includes(result.html, 'color:#000000')
    assert_includes(result.html, 'font-size:16px')
    assert_includes(result.html, 'border-radius:8px')
    assert_includes(result.html, 'padding:15px 30px')
    assert_includes(result.html, 'target="_self"')
    assert_includes(result.html, 'Buy Now')
  end

  def test_accordion_component_renders
    accordion = <<~MJML
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-accordion>
                <mj-accordion-element>
                  <mj-accordion-title>Section title</mj-accordion-title>
                  <mj-accordion-text>Section body</mj-accordion-text>
                </mj-accordion-element>
              </mj-accordion>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    result = MjmlRb::Compiler.new.compile(accordion)
    assert_empty(result.errors)
    assert_includes(result.html, "mj-accordion-title")
    assert_includes(result.html, "mj-accordion-content")
    assert_includes(result.html, "mj-accordion-checkbox")
    assert_includes(result.html, "Section title")
    assert_includes(result.html, "Section body")
  end

  def test_body_component_renders_attributes_and_context
    body = <<~MJML
      <mjml lang="ar" dir="rtl">
        <mj-head>
          <mj-title>Body Title</mj-title>
        </mj-head>
        <mj-body width="700px" background-color="#f5f5f5" css-class="body-class">
          <mj-section>
            <mj-column>
              <mj-text>Body Test</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    result = MjmlRb::Compiler.new.compile(body)
    assert_empty(result.errors)
    assert_includes(result.html, '<html lang="ar" dir="rtl">')
    assert_includes(result.html, '<body style="margin:0;padding:0;background:#f5f5f5">')
    assert_includes(result.html, 'aria-label="Body Title"')
    assert_includes(result.html, 'aria-roledescription="email"')
    assert_includes(result.html, 'class="body-class"')
    assert_includes(result.html, 'role="article"')
    assert_includes(result.html, 'max-width:700px')
  end

  def test_body_component_uses_default_width
    body = <<~MJML
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text>Default body width</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    result = MjmlRb::Compiler.new.compile(body)
    assert_empty(result.errors)

    assert_includes(result.html, 'max-width:600px')
    assert_includes(result.html, 'mj-column-per-100')
    assert_includes(result.html, 'Default body width')
  end

  def test_document_defaults_match_mjml_baseline_more_closely
    mjml = <<~MJML
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text>Defaults</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    result = MjmlRb::Compiler.new.compile(mjml)
    assert_empty(result.errors)
    assert_includes(result.html, '<html lang="und" dir="auto">')
    assert_includes(result.html, "<title></title>")
    assert_includes(result.html, 'https://fonts.googleapis.com/css?family=Roboto:300,400,500,700')
    refute_includes(result.html, 'https://fonts.googleapis.com/css?family=Open+Sans:300,400,500,700')
    refute_includes(result.html, 'https://fonts.googleapis.com/css?family=Droid+Sans:300,400,500,700')
    refute_includes(result.html, 'https://fonts.googleapis.com/css?family=Lato:300,400,500,700')
    refute_includes(result.html, 'https://fonts.googleapis.com/css?family=Ubuntu:300,400,500,700')
    assert_includes(result.html, 'lang="und" dir="auto"')
  end

  def test_section_component_applies_mj_class_background_radius_and_padding
    mjml = <<~MJML
      <mjml>
        <mj-head>
          <mj-attributes>
            <mj-class
              name="app-banner"
              background-color="#e0f5f3"
              border-radius="8px"
              padding-left="15px"
              padding-right="15px"
            />
          </mj-attributes>
        </mj-head>
        <mj-body>
          <mj-section mj-class="app-banner" css-class="app-bnr">
            <mj-column>
              <mj-table padding="0">
                <tr><td>Banner</td></tr>
              </mj-table>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    assert_empty(result.errors)
    assert_includes(result.html, 'class="app-bnr"')
    assert_includes(result.html, 'style="background:#e0f5f3;background-color:#e0f5f3;margin:0px auto;max-width:600px"')
    assert_includes(result.html, 'role="presentation" style="background:#e0f5f3;background-color:#e0f5f3;border-radius:8px;width:100%" width="100%"')
    assert_includes(result.html, 'align="center" bgcolor="#e0f5f3"')
    assert_includes(result.html, 'border-radius:8px')
    assert_includes(result.html, 'padding-left:15px')
    assert_includes(result.html, 'padding-right:15px')
    assert_includes(result.html, '<td align="left" style="font-size:0px;font-family:inherit;padding:0;word-break:break-word">')
  end

  def test_wrapper_accepts_full_width_in_strict_mode
    mjml = <<~MJML
      <mjml>
        <mj-body>
          <mj-wrapper full-width="full-width" background-color="#f0f0f0" css-class="hero-wrap">
            <mj-section>
              <mj-column>
                <mj-text>Wrapped</mj-text>
              </mj-column>
            </mj-section>
          </mj-wrapper>
        </mj-body>
      </mjml>
    MJML

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    assert_empty(result.errors)
    assert_includes(result.html, 'class="hero-wrap"')
    assert_includes(result.html, 'background:#f0f0f0')
    assert_includes(result.html, 'role="presentation" style="background:#f0f0f0;background-color:#f0f0f0;width:100%" width="100%"')
    assert_includes(result.html, "Wrapped")
  end

  def test_mj_html_attribute_applies_custom_attributes_to_rendered_nodes
    mjml = <<~MJML
      <mjml>
        <mj-head>
          <mj-html-attributes>
            <mj-selector path=".cta a">
              <mj-html-attribute name="data-track">primary</mj-html-attribute>
              <mj-html-attribute name="data-source">newsletter</mj-html-attribute>
            </mj-selector>
          </mj-html-attributes>
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-button css-class="cta" href="https://example.com">Click me</mj-button>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    result = MjmlRb::Compiler.new.compile(mjml)
    assert_empty(result.errors)
    assert_includes(result.html, 'data-track="primary"')
    assert_includes(result.html, 'data-source="newsletter"')
  end

  def test_mj_style_inline_applies_class_rules_to_rendered_markup
    mjml = <<~MJML
      <mjml>
        <mj-head>
          <mj-style inline="inline">
            .mail-body { background-color: #f5f5f5; padding-top: 10px; padding-bottom: 10px; }
            .app-bnr > table > tbody > tr > td { background-color: #e0f5f3; padding-left: 15px; padding-right: 15px; }
            .radius--top > table,
            .radius--top > table > tbody > tr > td { border-top-left-radius: 8px; border-top-right-radius: 8px; }
            .radius--bottom > table,
            .radius--bottom > table > tbody > tr > td { border-bottom-left-radius: 8px; border-bottom-right-radius: 8px; }
            .padding--none--this { padding: 0 !important; }
            .padding--top--s--this { padding-top: 10px !important; }
            .app-bnr--download-buttons { display: none; }
          </mj-style>
        </mj-head>
        <mj-body css-class="mail-body">
          <mj-section css-class="app-bnr radius--top radius--bottom">
            <mj-column>
              <mj-table css-class="padding--none--this">
                <tr>
                  <td class="padding--top--s--this">Cell</td>
                </tr>
                <tr>
                  <td class="app-bnr--download-buttons">Buttons</td>
                </tr>
              </mj-table>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    assert_empty(result.errors)
    assert_includes(result.html, 'class="mail-body"')
    assert_includes(result.html, 'background-color: #f5f5f5')
    assert_includes(result.html, 'padding-top: 10px')
    assert_includes(result.html, 'class="app-bnr radius--top radius--bottom"')
    assert_includes(result.html, 'border-top-left-radius: 8px')
    assert_includes(result.html, 'border-bottom-right-radius: 8px')
    assert_includes(result.html, 'background-color: #e0f5f3')
    assert_includes(result.html, 'padding-left: 15px')
    assert_includes(result.html, 'padding-right: 15px')
    assert_includes(result.html, 'class="padding--none--this"')
    assert_includes(result.html, 'padding: 0')
    assert_includes(result.html, 'class="padding--top--s--this"')
    assert_includes(result.html, 'padding-top: 10px')
    assert_includes(result.html, 'class="app-bnr--download-buttons"')
    assert_includes(result.html, 'display: none')
  end

  def test_mj_html_attribute_validates_metadata_in_strict_mode
    mjml = <<~MJML
      <mjml>
        <mj-head>
          <mj-html-attributes>
            <mj-selector extra="x">
              <mj-html-attribute invalid="x">primary</mj-html-attribute>
            </mj-selector>
          </mj-html-attributes>
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text>Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    messages = result.errors.map { |error| error[:message] }
    assert_includes(messages, "Attribute `extra` is not allowed for <mj-selector>")
    assert_includes(messages, "Attribute `invalid` is not allowed for <mj-html-attribute>")
  end

  def test_bare_ampersand_in_text_content
    mjml = <<~MJML
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text>Booking Terms & Conditions can be printed from below link:</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    result = MjmlRb::Compiler.new.compile(mjml)
    assert_empty(result.errors)
    assert_includes(result.html, "Terms &amp; Conditions")
  end

  def test_bare_ampersand_in_included_partial
    Dir.mktmpdir do |dir|
      partial = File.join(dir, "partial.mjml")
      main = File.join(dir, "main.mjml")
      File.write(partial, "<mj-text>Terms & Conditions apply</mj-text>")
      File.write(main, <<~MJML)
        <mjml>
          <mj-body>
            <mj-section>
              <mj-column>
                <mj-include path="./partial.mjml" />
              </mj-column>
            </mj-section>
          </mj-body>
        </mjml>
      MJML

      compiler = MjmlRb::Compiler.new(actual_path: main, file_path: dir)
      result = compiler.compile(File.read(main))
      assert_empty(result.errors)
      assert_includes(result.html, "Terms &amp; Conditions")
    end
  end

  def test_existing_entities_not_double_escaped
    mjml = <<~MJML
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text>Already escaped &amp; correct &#169; symbol</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    result = MjmlRb::Compiler.new.compile(mjml)
    assert_empty(result.errors)
    assert_includes(result.html, "&amp;")
    refute_includes(result.html, "&amp;amp;")
    # &#169; is decoded by XML parser to © — that's correct
    assert_includes(result.html, "©")
  end

  def test_closing_void_tags_stripped
    mjml = <<~MJML
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text>Line 1</br>Line 2</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    result = MjmlRb::Compiler.new.compile(mjml)
    assert_empty(result.errors)
    assert_includes(result.html, "Line 1")
    assert_includes(result.html, "Line 2")
  end

  def test_closing_void_tags_in_included_partial
    Dir.mktmpdir do |dir|
      partial = File.join(dir, "partial.mjml")
      main = File.join(dir, "main.mjml")
      File.write(partial, "<mj-text><table><tr><td>Terms</br>Conditions</td></tr></table></mj-text>")
      File.write(main, <<~MJML)
        <mjml>
          <mj-body>
            <mj-section>
              <mj-column>
                <mj-include path="./partial.mjml" />
              </mj-column>
            </mj-section>
          </mj-body>
        </mjml>
      MJML

      compiler = MjmlRb::Compiler.new(actual_path: main, file_path: dir)
      result = compiler.compile(File.read(main))
      assert_empty(result.errors)
      assert_includes(result.html, "Terms")
      assert_includes(result.html, "Conditions")
    end
  end

  def test_cli_compiles_file_to_output
    Dir.mktmpdir do |dir|
      input = File.join(dir, "email.mjml")
      output = File.join(dir, "email.html")
      File.write(input, SAMPLE)

      stdout = StringIO.new
      stderr = StringIO.new
      cli = MjmlRb::CLI.new(stdout: stdout, stderr: stderr)
      code = cli.run([input, "-o", output])

      assert_equal(0, code)
      assert(File.exist?(output))
      assert_includes(File.read(output), "Hello Ruby")
      assert_equal("", stderr.string)
    end
  end

  def test_cli_validate_reports_error
    Dir.mktmpdir do |dir|
      input = File.join(dir, "invalid.mjml")
      File.write(input, "<html />")

      stdout = StringIO.new
      stderr = StringIO.new
      cli = MjmlRb::CLI.new(stdout: stdout, stderr: stderr)
      code = cli.run(["--validate", input])

      assert_equal(1, code)
      assert_match(/Validation failed/, stderr.string)
    end
  end
end
