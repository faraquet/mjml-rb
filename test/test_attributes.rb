require "minitest/autorun"

require_relative "../lib/mjml-rb"

class MJMLAttributesTest < Minitest::Test
  FIXTURES_DIR = File.join(__dir__, "fixtures/attributes")

  def compile(mjml)
    MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
  end

  def expected(name)
    File.read(File.join(FIXTURES_DIR, "#{name}.html"))
  end

  def body_of(html)
    html[/<body[^>]*>(.*)<\/body>/m, 1].strip
  end

  def test_mj_attributes_supports_nested_mj_class_defaults_for_descendants
    result = compile(<<~MJML)
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

    assert_empty(result.errors)
    assert_equal expected("nested_mj_class"), body_of(result.html)
  end

  def test_mj_attributes_uses_nearest_mj_class_for_descendant_defaults
    result = compile(<<~MJML)
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

    assert_empty(result.errors)
    assert_equal expected("nearest_mj_class"), body_of(result.html)
  end
end
