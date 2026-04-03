require "minitest/autorun"

require_relative "../lib/mjml-rb"

class HtmlAttributesTest < Minitest::Test
  FIXTURES_DIR = File.join(__dir__, "fixtures/html_attributes")

  INPUT = <<~MJML
    <mjml>
      <mj-head>
        <mj-html-attributes>
          <mj-selector path=".text div">
            <mj-html-attribute name="data-id">42</mj-html-attribute>
          </mj-selector>
          <mj-selector path=".image td">
            <mj-html-attribute name="data-name">43</mj-html-attribute>
          </mj-selector>
        </mj-html-attributes>
      </mj-head>
      <mj-body>
        <mj-raw>{ if item < 5 }</mj-raw>
        <mj-section css-class="section">
          <mj-column>
            <mj-raw>{ if item > 10 }</mj-raw>
            <mj-text css-class="text">
              Hello World! { item }
            </mj-text>
            <mj-raw>{ end if }</mj-raw>
            <mj-text css-class="text">
              Hello World! { item + 1 }
            </mj-text>
            <mj-image css-class="image" src="https://via.placeholder.com/150x30" />
          </mj-column>
        </mj-section>
        <mj-raw>{ end if }</mj-raw>
      </mj-body>
    </mjml>
  MJML

  def compile(mjml, validation_level: "soft")
    MjmlRb::Compiler.new(validation_level: validation_level).compile(mjml)
  end

  def expected(name)
    File.read(File.join(FIXTURES_DIR, "#{name}.html"))
  end

  def test_puts_attributes_at_the_right_place_without_moving_raw_content
    result = compile(INPUT)
    assert_empty(result.errors)
    assert_equal expected("attributes_and_raw_content"), result.html
  end

  def test_validates_html_attribute_metadata_in_strict_mode
    result = compile(<<~MJML, validation_level: "strict")
      <mjml>
        <mj-head>
          <mj-html-attributes>
            <mj-selector extra="x">
              <mj-html-attribute invalid="x">primary</mj-html-attribute>
            </mj-selector>
          </mj-html-attributes>
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

    messages = result.errors.map { |error| error[:message] }
    assert_includes(messages, "Attribute `extra` is not allowed for <mj-selector>")
    assert_includes(messages, "Attribute `invalid` is not allowed for <mj-html-attribute>")
  end

  def test_applies_html_attributes_for_lang_pseudo_selector
    result = compile(<<~MJML)
      <mjml lang="ar">
        <mj-head>
          <mj-html-attributes>
            <mj-selector path=".caps:lang(ar)">
              <mj-html-attribute name="data-lang-match">yes</mj-html-attribute>
            </mj-selector>
          </mj-html-attributes>
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text css-class="caps">Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("lang_pseudo_selector"), result.html
  end

  def test_html_attributes_do_not_apply_to_head_markup
    result = compile(<<~MJML)
      <mjml>
        <mj-head>
          <mj-title>Welcome</mj-title>
          <mj-html-attributes>
            <mj-selector path="title">
              <mj-html-attribute name="data-head-mutated">yes</mj-html-attribute>
            </mj-selector>
            <mj-selector path=".copy div">
              <mj-html-attribute name="data-copy">ok</mj-html-attribute>
            </mj-selector>
          </mj-html-attributes>
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text css-class="copy">Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("no_head_mutation"), result.html
  end

  def test_html_attributes_run_before_inline_styles
    result = compile(<<~MJML, validation_level: "strict")
      <mjml>
        <mj-head>
          <mj-html-attributes>
            <mj-selector path=".copy div">
              <mj-html-attribute name="class">copy decorated</mj-html-attribute>
            </mj-selector>
          </mj-html-attributes>
          <mj-style inline="inline">
            .decorated { text-transform: uppercase; color: #ff0000; }
          </mj-style>
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text css-class="copy">Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("inline_styles_after_attributes"), result.html
  end
end
