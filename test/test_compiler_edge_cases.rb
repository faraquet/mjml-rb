require "minitest/autorun"

require_relative "../lib/mjml-rb"

class CompilerEdgeCasesTest < Minitest::Test
  def compile(mjml, **opts)
    MjmlRb::Compiler.new(**opts).compile(mjml)
  end

  SAMPLE = <<~MJML
    <mjml>
      <mj-body>
        <mj-section>
          <mj-column>
            <mj-text>Hello</mj-text>
          </mj-column>
        </mj-section>
      </mj-body>
    </mjml>
  MJML

  # --- validation_level: "skip" ---

  def test_skip_validation_returns_no_errors
    invalid_mjml = <<~MJML
      <mjml>
        <mj-body>
          <mj-text>Invalid: text not in section/column</mj-text>
        </mj-body>
      </mjml>
    MJML
    result = compile(invalid_mjml, validation_level: "skip")
    assert_empty result.errors
  end

  def test_skip_validation_still_produces_html
    result = compile(SAMPLE, validation_level: "skip")
    assert_includes result.html, "Hello"
    assert_includes result.html, "<!doctype html>"
  end

  # --- validation_level: "soft" ---

  def test_soft_validation_reports_warnings_but_still_renders
    invalid_mjml = <<~MJML
      <mjml>
        <mj-body>
          <mj-text>Invalid position</mj-text>
        </mj-body>
      </mjml>
    MJML
    result = compile(invalid_mjml, validation_level: "soft")
    refute_empty result.warnings
    assert_empty result.errors
    assert_includes result.html, "<!doctype html>"
  end

  # --- validation_level: "strict" ---

  def test_strict_validation_returns_empty_html_on_error
    invalid_mjml = <<~MJML
      <mjml>
        <mj-body>
          <mj-text>Invalid position</mj-text>
        </mj-body>
      </mjml>
    MJML
    result = compile(invalid_mjml, validation_level: "strict")
    refute_empty result.errors
    assert_equal "", result.html
  end

  def test_strict_validation_passes_for_valid_document
    result = compile(SAMPLE, validation_level: "strict")
    assert_empty result.errors
    assert_includes result.html, "Hello"
  end

  # --- truthy? method ---

  def test_truthy_true
    compiler = MjmlRb::Compiler.new
    assert compiler.send(:truthy?, true)
  end

  def test_truthy_false
    compiler = MjmlRb::Compiler.new
    refute compiler.send(:truthy?, false)
  end

  def test_truthy_string_true
    compiler = MjmlRb::Compiler.new
    assert compiler.send(:truthy?, "true")
  end

  def test_truthy_string_false
    compiler = MjmlRb::Compiler.new
    refute compiler.send(:truthy?, "false")
  end

  def test_truthy_string_yes
    compiler = MjmlRb::Compiler.new
    assert compiler.send(:truthy?, "yes")
  end

  def test_truthy_string_no
    compiler = MjmlRb::Compiler.new
    refute compiler.send(:truthy?, "no")
  end

  def test_truthy_string_zero
    compiler = MjmlRb::Compiler.new
    refute compiler.send(:truthy?, "0")
  end

  def test_truthy_string_off
    compiler = MjmlRb::Compiler.new
    refute compiler.send(:truthy?, "off")
  end

  def test_truthy_arbitrary_string
    compiler = MjmlRb::Compiler.new
    assert compiler.send(:truthy?, "anything")
  end

  # --- symbolize_keys ---

  def test_symbolize_keys_basic
    compiler = MjmlRb::Compiler.new
    result = compiler.send(:symbolize_keys, { "foo" => 1, "bar" => 2 })
    assert_equal({ foo: 1, bar: 2 }, result)
  end

  def test_symbolize_keys_converts_dashes_to_underscores
    compiler = MjmlRb::Compiler.new
    result = compiler.send(:symbolize_keys, { "keep-comments" => true, "validation-level" => "strict" })
    assert_equal({ keep_comments: true, validation_level: "strict" }, result)
  end

  def test_symbolize_keys_handles_symbol_keys
    compiler = MjmlRb::Compiler.new
    result = compiler.send(:symbolize_keys, { foo: 1 })
    assert_equal({ foo: 1 }, result)
  end

  # --- strip_comments ---

  def test_strip_comments_removes_html_comments
    compiler = MjmlRb::Compiler.new
    result = compiler.send(:strip_comments, "before<!-- comment -->after")
    assert_equal "beforeafter", result
  end

  def test_strip_comments_removes_multiline_comments
    compiler = MjmlRb::Compiler.new
    html = "before<!--\nmultiline\ncomment\n-->after"
    result = compiler.send(:strip_comments, html)
    assert_equal "beforeafter", result
  end

  def test_strip_comments_preserves_non_comment_content
    compiler = MjmlRb::Compiler.new
    html = "<div>Hello</div>"
    result = compiler.send(:strip_comments, html)
    assert_equal "<div>Hello</div>", result
  end

  # --- beautify ---

  def test_beautify_adds_newlines_between_tags
    compiler = MjmlRb::Compiler.new
    result = compiler.send(:beautify, "<div><p>Hello</p></div>")
    assert_includes result, ">\n<"
  end

  # --- minify ---

  def test_minify_removes_whitespace_between_tags
    compiler = MjmlRb::Compiler.new
    result = compiler.send(:minify, "<div>   <p>Hello</p>   </div>")
    assert_includes result, "><p>"
    refute_match(/>\s{2,}</, result)
  end

  # --- format_error ---

  def test_format_error_without_line
    compiler = MjmlRb::Compiler.new
    error = compiler.send(:format_error, "Something went wrong")
    assert_equal "Something went wrong", error[:message]
    assert_equal "Something went wrong", error[:formatted_message]
    assert_nil error[:line]
    assert_nil error[:tag_name]
  end

  def test_format_error_with_line
    compiler = MjmlRb::Compiler.new
    error = compiler.send(:format_error, "Bad stuff", line: 42)
    assert_equal 42, error[:line]
    assert_equal "Bad stuff", error[:message]
  end

  # --- Error handling ---

  def test_parse_error_produces_result_with_error
    result = compile("<mjml><unclosed>")
    refute result.success?
    assert result.errors.any? { |e| e[:message].include?("parse error") || e[:message].include?("Missing") }
  end

  def test_completely_invalid_input_produces_error
    result = compile("")
    refute result.success?
  end

  # --- mjml2html convenience ---

  def test_mjml2html_returns_hash
    result = MjmlRb.mjml2html(SAMPLE)
    assert_instance_of Hash, result
    assert result.key?(:html)
    assert result.key?(:errors)
    assert result.key?(:warnings)
  end

  def test_to_html_alias
    result = MjmlRb.to_html(SAMPLE)
    assert_instance_of Hash, result
    assert_includes result[:html], "Hello"
  end

  # --- Compiler with string keys in options ---

  def test_compiler_accepts_string_keys
    result = MjmlRb::Compiler.new("validation-level" => "strict", "keep-comments" => false).compile(SAMPLE)
    assert result.success?
    refute_includes result.html, "<!--"
  end

  # --- mjml2html alias ---

  def test_compiler_mjml2html_alias
    compiler = MjmlRb::Compiler.new
    result = compiler.mjml2html(SAMPLE)
    assert_instance_of MjmlRb::Result, result
    assert_includes result.html, "Hello"
  end

  # --- Preprocessors through compiler ---

  def test_preprocessors_option
    preprocessor = ->(xml) { xml.gsub("REPLACED", "Hello") }
    mjml = <<~MJML
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text>REPLACED</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    result = compile(mjml, preprocessors: [preprocessor])
    assert result.success?
    assert_includes result.html, "Hello"
  end
end
