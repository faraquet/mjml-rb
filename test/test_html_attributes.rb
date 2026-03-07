require "minitest/autorun"
require "nokogiri"

require_relative "../lib/mjml-rb"

class HtmlAttributesTest < Minitest::Test
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

  def test_puts_attributes_at_the_right_place_without_moving_raw_content
    result = compile(INPUT)
    assert_empty(result.errors)

    document = Nokogiri::HTML(result.html)

    text_ids = document.css(".text div").map { |node| node["data-id"] }
    image_names = document.css(".image td").map { |node| node["data-name"] }

    assert_equal(["42", "42"], text_ids)
    assert_equal(["43"], image_names)

    expected = [
      "{ if item &lt; 5 }",
      'class="section"',
      "{ if item &gt; 10 }",
      'class="text"',
      "{ item }",
      "{ end if }",
      "{ item + 1 }"
    ]
    indexes = expected.map { |fragment| result.html.index(fragment) }

    refute_includes(indexes, nil)
    assert_equal(indexes.sort, indexes)
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
end
