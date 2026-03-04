require "minitest/autorun"
require "tmpdir"
require "stringio"

require_relative "../lib/mjml_rb"

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
    assert_includes(result.html, 'width="700px"')
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

    expected_html = <<~HTML
      <!doctype html>
      <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>MJML Document</title>
          <link href="https://fonts.googleapis.com/css?family=Open+Sans:300,400,500,700" rel="stylesheet" type="text/css">
      <link href="https://fonts.googleapis.com/css?family=Droid+Sans:300,400,500,700" rel="stylesheet" type="text/css">
      <link href="https://fonts.googleapis.com/css?family=Lato:300,400,500,700" rel="stylesheet" type="text/css">
      <link href="https://fonts.googleapis.com/css?family=Roboto:300,400,500,700" rel="stylesheet" type="text/css">
      <link href="https://fonts.googleapis.com/css?family=Ubuntu:300,400,500,700" rel="stylesheet" type="text/css">
          <style type="text/css"></style>
        </head>
        <body style="margin:0;padding:0;background:#ffffff">
          
          <div aria-roledescription="email" role="article" lang="en"><table role="presentation" align="center" width="600px" cellspacing="0" cellpadding="0" border="0" style="width:100%;max-width:600px;margin:0 auto"><tbody><tr><td style="padding:20px 0"><table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0"><tbody><tr><td valign="top"><table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0"><tbody><tr><td style="font-family:Arial, sans-serif;font-size:13px;line-height:1.5;color:#000000;padding:10px 25px">Default body width</td></tr></tbody></table></td></tr></tbody></table></td></tr></tbody></table></div>
        </body>
      </html>
    HTML

    assert_equal(expected_html, result.html)
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
