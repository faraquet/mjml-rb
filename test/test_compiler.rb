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
    assert_includes(result.html, "<tr><td>A</td></tr>")
    assert_includes(result.html, "<tr><td>B</td></tr>")
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
