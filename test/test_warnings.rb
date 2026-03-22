require "minitest/autorun"

require_relative "../lib/mjml-rb"

class WarningsTest < Minitest::Test
  def compile(mjml, **opts)
    MjmlRb::Compiler.new(**opts).compile(mjml)
  end

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

  INVALID_CHILD_MJML = <<~MJML
    <mjml>
      <mj-body>
        <mj-text>Text directly in body</mj-text>
      </mj-body>
    </mjml>
  MJML

  UNKNOWN_ATTR_MJML = <<~MJML
    <mjml>
      <mj-body>
        <mj-section>
          <mj-column>
            <mj-text fake-attribute="bad">Hello</mj-text>
          </mj-column>
        </mj-section>
      </mj-body>
    </mjml>
  MJML

  UNKNOWN_TAG_MJML = <<~MJML
    <mjml>
      <mj-body>
        <mj-section>
          <mj-column>
            <mj-nonexistent>Hello</mj-nonexistent>
          </mj-column>
        </mj-section>
      </mj-body>
    </mjml>
  MJML

  # --- Soft mode: issues become warnings, compilation continues ---

  def test_soft_mode_valid_doc_has_no_warnings
    result = compile(VALID_MJML, validation_level: "soft")
    assert result.success?
    assert_empty result.warnings
  end

  def test_soft_mode_invalid_child_produces_warnings_not_errors
    result = compile(INVALID_CHILD_MJML, validation_level: "soft")
    refute_empty result.warnings
    assert_empty result.errors
    assert result.success?
  end

  def test_soft_mode_still_renders_html
    result = compile(INVALID_CHILD_MJML, validation_level: "soft")
    assert_includes result.html, "<!doctype html>"
    assert_includes result.html, "Text directly in body"
  end

  def test_soft_mode_warning_has_correct_structure
    result = compile(INVALID_CHILD_MJML, validation_level: "soft")
    warning = result.warnings.first
    refute_nil warning
    assert warning.key?(:message)
    assert warning.key?(:tag_name)
    assert warning.key?(:formatted_message)
  end

  def test_soft_mode_unknown_attribute_produces_warning
    result = compile(UNKNOWN_ATTR_MJML, validation_level: "soft")
    refute_empty result.warnings
    assert_empty result.errors
    assert result.warnings.any? { |w| w[:message].include?("fake-attribute") }
  end

  def test_soft_mode_unknown_tag_produces_warning
    result = compile(UNKNOWN_TAG_MJML, validation_level: "soft")
    refute_empty result.warnings
    assert_empty result.errors
    assert result.warnings.any? { |w| w[:message].include?("mj-nonexistent") }
  end

  # --- Strict mode: issues become errors, compilation may stop ---

  def test_strict_mode_valid_doc_has_no_errors_or_warnings
    result = compile(VALID_MJML, validation_level: "strict")
    assert result.success?
    assert_empty result.errors
    assert_empty result.warnings
  end

  def test_strict_mode_invalid_child_produces_errors_not_warnings
    result = compile(INVALID_CHILD_MJML, validation_level: "strict")
    refute_empty result.errors
    assert_empty result.warnings
    refute result.success?
  end

  def test_strict_mode_stops_compilation_on_error
    result = compile(INVALID_CHILD_MJML, validation_level: "strict")
    # Strict mode should not produce HTML when there are errors
    assert_equal "", result.html
  end

  def test_strict_mode_unknown_attribute_produces_error
    result = compile(UNKNOWN_ATTR_MJML, validation_level: "strict")
    refute_empty result.errors
    assert_empty result.warnings
  end

  # --- Skip mode: no validation at all ---

  def test_skip_mode_no_warnings_or_errors
    result = compile(INVALID_CHILD_MJML, validation_level: "skip")
    assert_empty result.errors
    assert_empty result.warnings
    assert result.success?
  end

  def test_skip_mode_still_renders_html
    result = compile(INVALID_CHILD_MJML, validation_level: "skip")
    assert_includes result.html, "<!doctype html>"
  end

  # --- Result#to_h includes warnings ---

  def test_to_h_includes_warnings
    result = compile(INVALID_CHILD_MJML, validation_level: "soft")
    hash = result.to_h
    assert hash.key?(:warnings)
    refute_empty hash[:warnings]
  end

  # --- MjmlRb.mjml2html includes warnings ---

  def test_mjml2html_hash_includes_warnings
    hash = MjmlRb.mjml2html(INVALID_CHILD_MJML, validation_level: "soft")
    assert hash.key?(:warnings)
    refute_empty hash[:warnings]
  end

  # --- Multiple warnings accumulated ---

  def test_multiple_validation_issues_all_become_warnings_in_soft_mode
    mjml = <<~MJML
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text fake-one="a" fake-two="b">Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    result = compile(mjml, validation_level: "soft")
    assert result.warnings.size >= 2
    assert_empty result.errors
  end
end
