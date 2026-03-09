require "minitest/autorun"
require "nokogiri"

require_relative "../lib/mjml-rb"

class SocialTest < Minitest::Test
  def compile(mjml, validation_level: "strict")
    MjmlRb::Compiler.new(validation_level: validation_level).compile(mjml)
  end

  def validate(mjml)
    MjmlRb::Validator.new.validate(mjml)
  end

  def test_social_accepts_table_layout_attribute
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-social table-layout="fixed" mode="horizontal">
                <mj-social-element name="facebook" href="https://facebook.com">Facebook</mj-social-element>
              </mj-social>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty result.errors
    assert_includes result.html, "Facebook"
  end

  def test_social_rejects_invalid_table_layout_value
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-social table-layout="invalid">
                <mj-social-element name="facebook" href="https://facebook.com">Facebook</mj-social-element>
              </mj-social>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    table_layout_errors = errors.select { |e| e[:message].include?("table-layout") }
    refute_empty table_layout_errors
  end

  def test_social_rejects_unknown_attribute
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-social bogus="yes">
                <mj-social-element name="facebook" href="https://facebook.com">Facebook</mj-social-element>
              </mj-social>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    bogus_errors = errors.select { |e| e[:message].include?("bogus") }
    refute_empty bogus_errors
  end

  def test_social_element_validates_attributes
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-social>
                <mj-social-element name="facebook" href="https://facebook.com" align="center">Facebook</mj-social-element>
              </mj-social>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty errors
  end

  def test_social_element_rejects_unknown_attribute
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-social>
                <mj-social-element name="facebook" href="https://facebook.com" unknown-attr="yes">Facebook</mj-social-element>
              </mj-social>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    unknown_errors = errors.select { |e| e[:message].include?("unknown-attr") }
    refute_empty unknown_errors
  end

  def test_social_horizontal_rendering
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-social mode="horizontal" align="center">
                <mj-social-element name="facebook" href="https://facebook.com">Facebook</mj-social-element>
                <mj-social-element name="twitter" href="https://twitter.com">Twitter</mj-social-element>
              </mj-social>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty result.errors
    doc = Nokogiri::HTML(result.html)

    assert_includes result.html, "Facebook"
    assert_includes result.html, "Twitter"
    assert_includes result.html, "display:inline-table"
  end

  # Ported from upstream: social-align.test.js
  def test_social_element_align_renders_text_align_in_style
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-social mode="vertical">
                <mj-social-element name="facebook" href="https://mjml.io/" icon-position="right" align="right" css-class="my-social-element">
                  Facebook
                </mj-social-element>
              </mj-social>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty result.errors
    doc = Nokogiri::HTML(result.html)
    tr = doc.at_css("tr.my-social-element")
    refute_nil tr, "Expected a <tr> with class my-social-element"

    # The text <td> should have text-align:right
    text_td = tr.css("td").find { |td| td["style"]&.include?("text-align") }
    refute_nil text_td, "Expected a <td> with text-align style"
    assert_match(/text-align:\s*right/, text_td["style"])
  end

  # Ported from upstream: social-icon-height.test.js
  def test_social_icon_height_renders_in_td_style
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-social icon-height="40px">
                <mj-social-element name="facebook" href="https://mjml.io/" css-class="my-social-element">
                  Facebook
                </mj-social-element>
              </mj-social>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty result.errors
    doc = Nokogiri::HTML(result.html)
    tr = doc.at_css("tr.my-social-element")
    refute_nil tr, "Expected a <tr> with class my-social-element"

    # The icon <td> should have height:40px in its style
    icon_td = tr.css("td").find { |td| td["style"]&.match?(/height:\s*40px/) }
    refute_nil icon_td, "Expected a <td> with height:40px style"
  end

  def test_social_vertical_rendering
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-social mode="vertical">
                <mj-social-element name="github" href="https://github.com">GitHub</mj-social-element>
              </mj-social>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty result.errors
    assert_includes result.html, "GitHub"
  end
end
