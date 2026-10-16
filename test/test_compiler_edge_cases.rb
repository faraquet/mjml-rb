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

  def test_boolean_options_require_boolean_values
    %w[true false yes no 0 off anything].each do |value|
      assert_raises(ArgumentError) { compile(SAMPLE, minify: value) }
    end
  end

  def test_options_normalize_dashes_and_camel_case
    assert_equal({keep_comments: false, validation_level: "strict"},
                 MjmlRb::Options.normalize("keepComments" => false, "validation-level" => "strict"))
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
    assert_includes result.html, "<!--[if mso]>"
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
