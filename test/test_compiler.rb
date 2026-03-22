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

  def test_document_shell_includes_mjml_scaffold_helpers
    result = MjmlRb.mjml2html(SAMPLE)
    html = result[:html]

    assert_empty(result[:errors])
    assert_includes(html, 'xmlns="http://www.w3.org/1999/xhtml"')
    assert_includes(html, 'xmlns:v="urn:schemas-microsoft-com:vml"')
    assert_includes(html, 'xmlns:o="urn:schemas-microsoft-com:office:office"')
    assert_includes(html, '<meta http-equiv="X-UA-Compatible" content="IE=edge">')
    assert_includes(html, '<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">')
    refute_includes(html, '<meta charset="utf-8">')
    assert_includes(html, "<o:PixelsPerInch>96</o:PixelsPerInch>")
    assert_includes(html, ".mj-outlook-group-fix { width:100% !important; }")
    assert_includes(html, 'style="word-spacing:normal"')
    assert_includes(html, ".moz-text-html .mj-column-per-100")
    refute_includes(html, "@media only print")
    refute_includes(html, "[owa] .mj-column-per-100")
  end

  def test_owa_desktop_emits_owa_media_queries
    mjml = <<~MJML
      <mjml owa="desktop">
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text>Hello Ruby</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    result = MjmlRb.mjml2html(mjml)

    assert_empty(result[:errors])
    assert_includes(result[:html], "[owa] .mj-column-per-100")
  end

  def test_printer_support_emits_print_media_queries
    result = MjmlRb.mjml2html(SAMPLE, printer_support: true)

    assert_empty(result[:errors])
    assert_includes(result[:html], "@media only print")
    assert_includes(result[:html], ".mj-column-per-100 { width:100% !important; max-width: 100%; }")
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
    refute_empty(result.warnings)
    assert_match(/not allowed inside <mj-body>/, result.warnings.first[:message])
  end

  def test_globally_merges_adjacent_outlook_conditionals
    mjml = <<~MJML
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text>One</mj-text>
            </mj-column>
          </mj-section>
          <mj-section>
            <mj-column>
              <mj-text>Two</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    result = MjmlRb::Compiler.new.compile(mjml)

    assert_empty(result.errors)
    refute_match(/<!\[endif\]-->\s*<!--\[if mso \| IE\]>/m, result.html)
  end

  def test_minifies_whitespace_inside_outlook_conditionals
    renderer = MjmlRb::Renderer.new
    input = <<~HTML
      <div>
        <!--[if mso | IE]>
        <table
          align="center"
        >
          <tr>
            <td>Text</td>
          </tr>
        </table>
        <![endif]-->
      </div>
    HTML

    output = renderer.send(:minify_outlook_conditionals, input)

    assert_match(/<!--\[if mso \| IE\]><table align="center"\s*><tr><td>Text<\/td><\/tr><\/table><!\[endif\]-->/, output)
    refute_match(/<!--\[if mso \| IE\]>\s+</m, output)
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

  def test_include_expansion_wraps_bare_mjml_fragments
    Dir.mktmpdir do |dir|
      partial = File.join(dir, "partial.mjml")
      main = File.join(dir, "main.mjml")
      File.write(partial, <<~MJML)
        <mj-text>Bare include</mj-text>
        <mj-button href="https://example.com">Go</mj-button>
      MJML
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
      assert_includes(result.html, "Bare include")
      assert_includes(result.html, ">Go<")
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
    assert_includes(result.html, '<html lang="und" dir="auto" xmlns="http://www.w3.org/1999/xhtml"')
    assert_includes(result.html, "<title></title>")
    assert_includes(result.html, 'table, td { border-collapse:collapse;mso-table-lspace:0pt;mso-table-rspace:0pt; }')
    refute_includes(result.html, 'https://fonts.googleapis.com/css?family=Roboto:300,400,500,700')
    refute_includes(result.html, 'https://fonts.googleapis.com/css?family=Open+Sans:300,400,500,700')
    refute_includes(result.html, 'https://fonts.googleapis.com/css?family=Droid+Sans:300,400,500,700')
    refute_includes(result.html, 'https://fonts.googleapis.com/css?family=Lato:300,400,500,700')
    assert_includes(result.html, 'https://fonts.googleapis.com/css?family=Ubuntu:300,400,500,700')
    assert_includes(result.html, 'lang="und" dir="auto"')
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
    # &#169; is preserved as-is in CDATA-wrapped ending-tag content,
    # matching npm behavior (decodeEntities: false). Both &#169; and ©
    # render identically in browsers.
    assert_includes(result.html, "&#169;")
  end

  def test_malformed_closing_br_is_recovered_as_line_break
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
    assert_includes(result.html, "Line 1<br />Line 2")
  end

  def test_empty_non_void_html_tags_are_not_self_closed_in_mj_text
    mjml = <<~MJML
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text><p></p><p>A</p><p>B</p><p></p></mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    result = MjmlRb::Compiler.new.compile(mjml)
    assert_empty(result.errors)
    assert_includes(result.html, "<p></p><p>A</p><p>B</p><p></p>")
    refute_includes(result.html, "<p />")
  end

  def test_inline_style_postprocess_preserves_html5_paragraph_recovery
    mjml = <<~MJML
      <mjml>
        <mj-head>
          <mj-style inline="inline">p { color: #333333; }</mj-style>
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text><p class="padding--top--none--this"><p>One</p><p>Two</p></p></mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    result = MjmlRb::Compiler.new.compile(mjml)
    assert_empty(result.errors)
    assert_includes(result.html, '<p class="padding--top--none--this"')
    assert_match(%r{<p class="padding--top--none--this"[^>]*></p><p[^>]*>One</p><p[^>]*>Two</p><p[^>]*></p>}m, result.html)
  end

  def test_include_type_css_adds_style_to_head
    Dir.mktmpdir do |dir|
      css_file = File.join(dir, "style.css")
      main = File.join(dir, "main.mjml")
      File.write(css_file, ".custom { color: red; }")
      File.write(main, <<~MJML)
        <mjml>
          <mj-head></mj-head>
          <mj-body>
            <mj-section>
              <mj-column>
                <mj-include path="./style.css" type="css" />
                <mj-text css-class="custom">Styled</mj-text>
              </mj-column>
            </mj-section>
          </mj-body>
        </mjml>
      MJML

      compiler = MjmlRb::Compiler.new(actual_path: main, file_path: dir)
      result = compiler.compile(File.read(main))
      assert_empty(result.errors)
      assert_includes(result.html, ".custom { color: red; }")
      assert_includes(result.html, "Styled")
    end
  end

  def test_include_type_css_inline_applies_inline_styles
    Dir.mktmpdir do |dir|
      css_file = File.join(dir, "inline.css")
      main = File.join(dir, "main.mjml")
      File.write(css_file, "p { color: #ff0000; }")
      File.write(main, <<~MJML)
        <mjml>
          <mj-head></mj-head>
          <mj-body>
            <mj-section>
              <mj-column>
                <mj-include path="./inline.css" type="css" css-inline="inline" />
                <mj-text><p>Inline styled</p></mj-text>
              </mj-column>
            </mj-section>
          </mj-body>
        </mjml>
      MJML

      compiler = MjmlRb::Compiler.new(actual_path: main, file_path: dir)
      result = compiler.compile(File.read(main))
      assert_empty(result.errors)
      assert_match(/color:\s*#ff0000/, result.html)
    end
  end

  def test_include_type_css_creates_head_if_missing
    Dir.mktmpdir do |dir|
      css_file = File.join(dir, "style.css")
      main = File.join(dir, "main.mjml")
      File.write(css_file, ".custom { font-size: 16px; }")
      File.write(main, <<~MJML)
        <mjml>
          <mj-body>
            <mj-section>
              <mj-column>
                <mj-include path="./style.css" type="css" />
                <mj-text css-class="custom">No head</mj-text>
              </mj-column>
            </mj-section>
          </mj-body>
        </mjml>
      MJML

      compiler = MjmlRb::Compiler.new(actual_path: main, file_path: dir)
      result = compiler.compile(File.read(main))
      assert_empty(result.errors)
      assert_includes(result.html, ".custom { font-size: 16px; }")
    end
  end

  def test_circular_include_detected
    Dir.mktmpdir do |dir|
      file_a = File.join(dir, "a.mjml")
      file_b = File.join(dir, "b.mjml")
      main = File.join(dir, "main.mjml")
      # a includes b, b includes a — indirect circular reference
      File.write(file_a, '<mj-wrapper><mj-include path="./b.mjml" /></mj-wrapper>')
      File.write(file_b, '<mj-wrapper><mj-include path="./a.mjml" /></mj-wrapper>')
      File.write(main, <<~MJML)
        <mjml>
          <mj-body>
            <mj-section>
              <mj-column>
                <mj-include path="./a.mjml" />
              </mj-column>
            </mj-section>
          </mj-body>
        </mjml>
      MJML

      compiler = MjmlRb::Compiler.new(actual_path: main, file_path: dir)
      result = compiler.compile(File.read(main))
      refute_empty(result.errors)
      assert_match(/Circular inclusion detected/, result.errors.first[:message])
    end
  end

  def test_missing_include_file_produces_error_comment
    Dir.mktmpdir do |dir|
      main = File.join(dir, "main.mjml")
      File.write(main, <<~MJML)
        <mjml>
          <mj-body>
            <mj-section>
              <mj-column>
                <mj-include path="./nonexistent.mjml" />
                <mj-text>Still here</mj-text>
              </mj-column>
            </mj-section>
          </mj-body>
        </mjml>
      MJML

      compiler = MjmlRb::Compiler.new(actual_path: main, file_path: dir)
      result = compiler.compile(File.read(main))
      assert_includes(result.html, "mj-include fails to read file")
      assert_includes(result.html, "Still here")
    end
  end

  def test_missing_css_include_file_produces_error_comment
    Dir.mktmpdir do |dir|
      main = File.join(dir, "main.mjml")
      File.write(main, <<~MJML)
        <mjml>
          <mj-body>
            <mj-section>
              <mj-column>
                <mj-include path="./nonexistent.css" type="css" />
                <mj-text>Still here</mj-text>
              </mj-column>
            </mj-section>
          </mj-body>
        </mjml>
      MJML

      compiler = MjmlRb::Compiler.new(actual_path: main, file_path: dir)
      result = compiler.compile(File.read(main))
      assert_includes(result.html, "mj-include fails to read file")
      assert_includes(result.html, "Still here")
    end
  end

  def test_malformed_closing_br_in_included_partial_is_recovered
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
      assert_includes(result.html, "Terms<br />Conditions")
    end
  end

  def test_malformed_closing_br_is_preserved_inside_mj_table_content
    mjml = <<~MJML
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-table>
                <tr>
                  <td><span>A</span></br><span>B</span></td>
                </tr>
              </mj-table>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    result = MjmlRb::Compiler.new.compile(mjml)
    assert_empty(result.errors)
    assert_includes(result.html, "<span>A</span><br /><span>B</span>")
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
