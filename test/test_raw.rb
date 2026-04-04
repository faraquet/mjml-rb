require "minitest/autorun"

require_relative "../lib/mjml-rb"

class MJMLRawTest < Minitest::Test
  FIXTURES_DIR = File.join(__dir__, "fixtures/raw")

  def compile(mjml)
    MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
  end

  def expected(name)
    File.read(File.join(FIXTURES_DIR, "#{name}.html"))
  end

  def body_of(html)
    html[/<body[^>]*>(.*)<\/body>/m, 1].strip
  end

  def test_mj_raw_allows_html_children_in_strict_mode
    result = compile(<<~MJML)
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

    assert_empty(result.errors)
    assert_equal expected("html_children_strict"), body_of(result.html)
  end

  def test_mj_raw_in_head_is_emitted_at_end_of_head
    result = compile(<<~MJML)
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

    assert_empty(result.errors)
    assert_equal expected("head_raw"), body_of(result.html)
  end

  def test_mj_raw_file_start_is_emitted_before_doctype
    result = compile(<<~MJML)
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

    assert_empty(result.errors)
    assert_equal expected("file_start"), body_of(result.html)
  end
end
