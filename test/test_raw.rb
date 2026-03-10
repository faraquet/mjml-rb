require "minitest/autorun"

require_relative "../lib/mjml-rb"

class MJMLRawTest < Minitest::Test
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

  def test_mj_raw_in_head_is_emitted_at_end_of_head
    mjml = <<~MJML
      <mjml>
        <mj-head>
          <mj-raw><meta name="x-head" content="1" /></mj-raw>
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
    assert_empty(result.errors)
    assert_match(%r{<style type="text/css">.*</style>\s*<meta name="x-head" content="1" />\s*</head>}m, result.html)
  end

  def test_mj_raw_file_start_is_emitted_before_doctype
    mjml = <<~MJML
      <mjml>
        <mj-raw position="file-start">before doctype</mj-raw>
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
    assert_empty(result.errors)
    assert_match(/\Abefore doctype\s*<!doctype html>/m, result.html)
  end
end
