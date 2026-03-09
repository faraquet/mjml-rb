require "minitest/autorun"
require "nokogiri"

require_relative "../lib/mjml-rb"

class AccordionTest < Minitest::Test
  def compile(mjml, validation_level: "soft")
    MjmlRb::Compiler.new(validation_level: validation_level).compile(mjml)
  end

  private

  def extract_style_value(style, property)
    return nil unless style
    start = style.index("#{property}:")
    return nil unless start
    start += property.length + 1
    finish = style.index(";", start)
    style[start...finish]&.strip
  end

  public

  # Ported from upstream: accordion-fontFamily.test.js
  def test_accordion_font_family_inheritance
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-accordion css-class="my-accordion-1" font-family="serif">
                <mj-accordion-element>
                  <mj-accordion-title>Why use an accordion?</mj-accordion-title>
                  <mj-accordion-text>
                      Because emails with a lot of content are most of the time a very bad experience on mobile, mj-accordion comes handy when you want to deliver a lot of information in a concise way.
                  </mj-accordion-text>
                </mj-accordion-element>
              </mj-accordion>
            </mj-column>
          </mj-section>
          <mj-section>
            <mj-column>
              <mj-accordion css-class="my-accordion-2" font-family="serif">
                <mj-accordion-element font-family="sans-serif">
                  <mj-accordion-title font-family="monospace">Why use an accordion?</mj-accordion-title>
                  <mj-accordion-text font-family="monospace">
                      Because emails with a lot of content are most of the time a very bad experience on mobile, mj-accordion comes handy when you want to deliver a lot of information in a concise way.
                  </mj-accordion-text>
                </mj-accordion-element>
              </mj-accordion>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty result.errors
    doc = Nokogiri::HTML(result.html)

    # First accordion: title and text should inherit serif from mj-accordion
    acc1_title_td = doc.at_css(".my-accordion-1 .mj-accordion-title td:first-child")
    acc1_text_td = doc.at_css(".my-accordion-1 .mj-accordion-content td:first-child")
    refute_nil acc1_title_td, "Expected accordion-1 title td"
    refute_nil acc1_text_td, "Expected accordion-1 text td"
    assert_equal "serif", extract_style_value(acc1_title_td["style"], "font-family")
    assert_equal "serif", extract_style_value(acc1_text_td["style"], "font-family")

    # Second accordion: title and text should use explicit monospace
    acc2_title_td = doc.at_css(".my-accordion-2 .mj-accordion-title td:first-child")
    acc2_text_td = doc.at_css(".my-accordion-2 .mj-accordion-content td:first-child")
    refute_nil acc2_title_td, "Expected accordion-2 title td"
    refute_nil acc2_text_td, "Expected accordion-2 text td"
    assert_equal "monospace", extract_style_value(acc2_title_td["style"], "font-family")
    assert_equal "monospace", extract_style_value(acc2_text_td["style"], "font-family")
  end

  # Ported from upstream: accordion-padding.test.js
  def test_accordion_padding_overrides
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-accordion>
                <mj-accordion-element>
                  <mj-accordion-title padding="20px" padding-bottom="40px" padding-left="40px" padding-right="40px" padding-top="40px">Why use an accordion?</mj-accordion-title>
                  <mj-accordion-text padding="20px" padding-bottom="40px" padding-left="40px" padding-right="40px" padding-top="40px">
                      Because emails with a lot of content are most of the time a very bad experience on mobile, mj-accordion comes handy when you want to deliver a lot of information in a concise way.
                  </mj-accordion-text>
                </mj-accordion-element>
              </mj-accordion>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty result.errors
    doc = Nokogiri::HTML(result.html)

    tds = doc.css(".mj-accordion-title td:first-child, .mj-accordion-content td:first-child")
    assert_equal 2, tds.length, "Expected title td and text td"

    %w[padding-left padding-right padding-top padding-bottom].each do |prop|
      values = tds.map { |td| extract_style_value(td["style"], prop) }
      assert_equal ["40px", "40px"], values, "#{prop} should be 40px on both title and text"
    end
  end

  # Ported from upstream: accordionTitle-fontWeight.test.js
  # Uses validation_level: "skip" because mj-accordion-text contains <span> children,
  # which npm treats as raw content (ending-tag) but Ruby's validator flags.
  def test_accordion_title_font_weight
    result = compile(<<~MJML, validation_level: "skip")
      <mjml>
        <mj-head>
          <mj-attributes>
            <mj-accordion border="none" padding="1px" />
            <mj-accordion-element icon-wrapped-url="https://i.imgur.com/Xvw0vjq.png" icon-unwrapped-url="https://i.imgur.com/KKHenWa.png" icon-height="24px" icon-width="24px" />
            <mj-accordion-title font-family="Roboto, Open Sans, Helvetica, Arial, sans-serif" background-color="#fff" color="#031017" padding="15px" font-size="18px" />
            <mj-accordion-text font-family="Open Sans, Helvetica, Arial, sans-serif" background-color="#fafafa" padding="15px" color="#505050" font-size="14px" />
          </mj-attributes>
        </mj-head>
        <mj-body>
          <mj-section padding="20px" background-color="#ffffff">
            <mj-column background-color="#dededd">
              <mj-accordion>
                <mj-accordion-element>
                  <mj-accordion-title font-weight="bold" css-class="accordion-title">Why use an accordion?</mj-accordion-title>
                  <mj-accordion-text font-weight="bold">
                    <span style="line-height:20px">
                      Because emails with a lot of content are most of the time a very bad experience on mobile, mj-accordion comes handy when you want to deliver a lot of information in a concise way.
                    </span>
                  </mj-accordion-text>
                </mj-accordion-element>
                <mj-accordion-element>
                  <mj-accordion-title font-weight="700" css-class="accordion-title">How it works</mj-accordion-title>
                  <mj-accordion-text font-weight="700">
                    <span style="line-height:20px">
                      Content is stacked into tabs and users can expand them at will. If responsive styles are not supported (mostly on desktop clients), tabs are then expanded and your content is readable at once.
                    </span>
                  </mj-accordion-text>
                </mj-accordion-element>
              </mj-accordion>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    doc = Nokogiri::HTML(result.html)

    # Select the first <td> inside each .mj-accordion-title (the content cell with styling)
    title_tds = doc.css(".mj-accordion-title td:first-child")
    assert_equal 2, title_tds.length, "Expected 2 accordion title content cells"

    font_weights = title_tds.map { |td| extract_style_value(td["style"], "font-weight") }
    assert_equal ["bold", "700"], font_weights
  end
end
