require "minitest/autorun"

require_relative "../lib/mjml-rb"

class OptionValidationTest < Minitest::Test
  VALID_MJML = <<~MJML
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

  # =========================================================================
  # validation_level must be one of "soft", "strict", "skip"
  # =========================================================================

  def test_accepts_validation_level_soft
    compiler = MjmlRb::Compiler.new(validation_level: "soft")
    result = compiler.compile(VALID_MJML)
    assert result.success?
  end

  def test_accepts_validation_level_strict
    compiler = MjmlRb::Compiler.new(validation_level: "strict")
    result = compiler.compile(VALID_MJML)
    assert result.success?
  end

  def test_accepts_validation_level_skip
    compiler = MjmlRb::Compiler.new(validation_level: "skip")
    result = compiler.compile(VALID_MJML)
    assert result.success?
  end

  def test_rejects_invalid_validation_level_in_constructor
    error = assert_raises(ArgumentError) do
      MjmlRb::Compiler.new(validation_level: "banana")
    end
    assert_includes error.message, "validation_level"
    assert_includes error.message, "banana"
  end

  def test_rejects_invalid_validation_level_in_compile
    compiler = MjmlRb::Compiler.new
    error = assert_raises(ArgumentError) do
      compiler.compile(VALID_MJML, validation_level: "invalid")
    end
    assert_includes error.message, "validation_level"
  end

  # =========================================================================
  # Unknown option keys should raise
  # =========================================================================

  def test_rejects_unknown_option_in_constructor
    error = assert_raises(ArgumentError) do
      MjmlRb::Compiler.new(nonexistent_option: true)
    end
    assert_includes error.message, "nonexistent_option"
  end

  def test_rejects_unknown_option_in_compile
    compiler = MjmlRb::Compiler.new
    error = assert_raises(ArgumentError) do
      compiler.compile(VALID_MJML, unknown_key: "value")
    end
    assert_includes error.message, "unknown_key"
  end

  def test_rejects_multiple_unknown_options
    error = assert_raises(ArgumentError) do
      MjmlRb::Compiler.new(bad_one: 1, bad_two: 2)
    end
    assert_includes error.message, "bad_one"
    assert_includes error.message, "bad_two"
  end

  # =========================================================================
  # All valid option keys should be accepted
  # =========================================================================

  def test_accepts_all_valid_options
    compiler = MjmlRb::Compiler.new(
      beautify: true,
      minify: false,
      keep_comments: true,
      ignore_includes: false,
      printer_support: false,
      preprocessors: [],
      validation_level: "soft",
      file_path: ".",
      actual_path: ".",
      lang: "en",
      dir: "ltr",
      fonts: {}
    )
    result = compiler.compile(VALID_MJML)
    assert result.success?
  end

  # =========================================================================
  # Dashed keys are normalized and accepted
  # =========================================================================

  def test_accepts_dashed_key_variants
    compiler = MjmlRb::Compiler.new("validation-level" => "strict", "keep-comments" => false)
    result = compiler.compile(VALID_MJML)
    assert result.success?
  end

  def test_rejects_unknown_dashed_key
    error = assert_raises(ArgumentError) do
      MjmlRb::Compiler.new("not-a-real-option" => true)
    end
    assert_includes error.message, "not_a_real_option"
  end

  # =========================================================================
  # MjmlRb.mjml2html also validates options
  # =========================================================================

  def test_mjml2html_rejects_invalid_validation_level
    error = assert_raises(ArgumentError) do
      MjmlRb.mjml2html(VALID_MJML, validation_level: "nope")
    end
    assert_includes error.message, "validation_level"
  end

  def test_mjml2html_rejects_unknown_option
    error = assert_raises(ArgumentError) do
      MjmlRb.mjml2html(VALID_MJML, bogus: true)
    end
    assert_includes error.message, "bogus"
  end
end
