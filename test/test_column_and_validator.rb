require "minitest/autorun"

require_relative "../lib/mjml-rb"

class MJMLColumnAndValidatorTest < Minitest::Test
  def compile(mjml, validation_level: "soft")
    MjmlRb::Compiler.new(validation_level: validation_level).compile(mjml)
  end

  def validate(mjml)
    MjmlRb::Validator.new.validate(mjml)
  end

  def test_column_without_gutter_keeps_flat_structure
    result = compile(<<~MJML)
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

    assert_empty(result.errors)
    assert_includes(result.html, 'class="mj-column-per-100 mj-outlook-group-fix"')
    assert_includes(result.html, 'direction:ltr')
    assert_match(%r{<table[^>]*role="presentation"[^>]*width="100%"[^>]*style="vertical-align:top"[^>]*><tbody><tr><td align="left"}, result.html)
    refute_includes(result.html, '<td style="vertical-align:top;padding:')
  end

  def test_column_background_color_without_gutter_is_applied_to_table
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column background-color="#ffdddd">
              <mj-text>Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_includes(result.html, 'style="background-color:#ffdddd;vertical-align:top"')
  end

  def test_column_with_gutter_wraps_children_in_inner_td
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column background-color="#ffdddd" padding-top="12px" padding-right="34px" padding-bottom="56px" padding-left="78px">
              <mj-text>Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_includes(result.html, '<td style="background-color:#ffdddd;vertical-align:top;padding-top:12px;padding-right:34px;padding-bottom:56px;padding-left:78px">')
    assert_match(%r{<table[^>]*role="presentation"[^>]*width="100%"[^>]*><tbody><tr><td align="left"}, result.html)
  end

  def test_column_border_radius_and_inner_styles_follow_js_rendering
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column padding="12px" border-radius="8px" inner-background-color="#ddeeff" inner-border="1px solid #222222" inner-border-radius="6px" direction="rtl">
              <mj-text>Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_includes(result.html, 'direction:rtl')
    assert_includes(result.html, '<table border="0" cellpadding="0" cellspacing="0" role="presentation" width="100%" style="border-collapse:separate">')
    assert_includes(result.html, 'padding:12px')
    assert_includes(result.html, 'background-color:#ddeeff')
    assert_includes(result.html, 'border:1px solid #222222')
    assert_includes(result.html, 'border-radius:6px')
    assert_includes(result.html, 'border-collapse:separate')
  end

  def test_column_exposes_allowed_and_default_attributes
    assert_equal("color", MjmlRb::Components::Column.allowed_attributes["background-color"])
    assert_equal("enum(ltr,rtl)", MjmlRb::Components::Column.allowed_attributes["direction"])
    assert_equal("unit(px,%){1,4}", MjmlRb::Components::Column.allowed_attributes["padding"])
    assert_equal("ltr", MjmlRb::Components::Column.default_attributes["direction"])
    assert_equal("top", MjmlRb::Components::Column.default_attributes["vertical-align"])
  end

  def test_validator_accepts_supported_column_attributes
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column width="50%" padding="0 12px" direction="rtl" vertical-align="middle" css-class="hotel-column">
              <mj-text>Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(errors)
  end

  def test_validator_rejects_unsupported_column_attributes
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column nope="1">
              <mj-text>Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_includes(errors.map { |e| e[:message] }, "Attribute `nope` is not allowed for <mj-column>")
  end

  def test_validator_rejects_invalid_column_enum_values
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column vertical-align="center">
              <mj-text>Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_includes(errors.map { |e| e[:message] }, "Attribute `vertical-align` on <mj-column> has invalid value `center` for type `enum(top,bottom,middle)`")
  end

  def test_validator_rejects_invalid_column_unit_values
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column padding="12em">
              <mj-text>Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_includes(errors.map { |e| e[:message] }, "Attribute `padding` on <mj-column> has invalid value `12em` for type `unit(px,%){1,4}`")
  end
end
