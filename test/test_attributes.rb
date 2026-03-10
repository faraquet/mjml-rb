require "minitest/autorun"

require_relative "../lib/mjml-rb"

class MJMLAttributesTest < Minitest::Test
  def test_mj_attributes_supports_nested_mj_class_defaults_for_descendants
    mjml = <<~MJML
      <mjml>
        <mj-head>
          <mj-attributes>
            <mj-class name="promo" css-class="promo-root">
              <mj-text color="#ff0000" font-size="20px" />
            </mj-class>
          </mj-attributes>
        </mj-head>
        <mj-body>
          <mj-section mj-class="promo">
            <mj-column>
              <mj-text>Promo text</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    assert_empty(result.errors)
    assert_includes(result.html, 'class="promo-root"')
    assert_includes(result.html, 'font-size:20px')
    assert_includes(result.html, 'color:#ff0000')
    assert_includes(result.html, 'Promo text')
  end

  def test_mj_attributes_uses_nearest_mj_class_for_descendant_defaults
    mjml = <<~MJML
      <mjml>
        <mj-head>
          <mj-attributes>
            <mj-class name="outer">
              <mj-text color="#ff0000" />
            </mj-class>
            <mj-class name="inner">
              <mj-text color="#0000ff" />
            </mj-class>
          </mj-attributes>
        </mj-head>
        <mj-body>
          <mj-section mj-class="outer">
            <mj-column mj-class="inner">
              <mj-text>Nested text</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    assert_empty(result.errors)
    assert_includes(result.html, 'color:#0000ff')
    refute_includes(result.html, 'color:#ff0000')
  end
end
