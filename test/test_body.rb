require "minitest/autorun"

require_relative "../lib/mjml-rb"

class MJMLBodyTest < Minitest::Test
  FIXTURES_DIR = File.join(__dir__, "fixtures/body")

  def compile(mjml)
    MjmlRb::Compiler.new.compile(mjml)
  end

  def expected(name)
    File.read(File.join(FIXTURES_DIR, "#{name}.html"))
  end

  def test_body_owns_attributes_and_preview
    result = MjmlRb::Compiler.new(validation_level: "strict").compile(<<~MJML)
      <mjml lang="ar" dir="rtl">
        <mj-head>
          <mj-title>Subject</mj-title>
          <mj-preview>Preview</mj-preview>
          <mj-html-attributes>
            <mj-selector path="body"><mj-html-attribute name="data-test">yes</mj-html-attribute></mj-selector>
          </mj-html-attributes>
        </mj-head>
        <mj-body id="email" css-class="mail" background-color="#eee">
          <mj-section><mj-column><mj-text>Hello</mj-text></mj-column></mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    dom = Nokogiri::HTML(result.html)
    assert_equal 1, dom.css("body").size
    body = dom.at_css("body")
    assert_equal ["email", "mail", "yes"], %w[id class data-test].map { |name| body[name] }
    assert_equal "Preview", body.element_children.first.text
    article = body.at_css('[role="article"]')
    assert_equal ["Subject", "email", "ar", "rtl"], %w[aria-label aria-roledescription lang dir].map { |name| article[name] }
    assert_nil article["class"]
    assert_includes article["style"], "word-spacing:normal"
  end

  def test_body_component_renders_attributes_and_context
    result = compile(<<~MJML)
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

    assert_empty(result.errors)
    assert_includes result.html, expected("attributes_and_context")
  end

  def test_body_component_uses_default_width
    result = compile(<<~MJML)
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

    assert_empty(result.errors)
    assert_includes result.html, expected("default_width")
  end
end
