require "minitest/autorun"

require_relative "../lib/mjml-rb"

class WrapperTest < Minitest::Test
  FIXTURES_DIR = File.join(__dir__, "fixtures/wrapper")

  def compile(mjml, validation_level: "strict")
    MjmlRb::Compiler.new(validation_level: validation_level).compile(mjml)
  end

  def expected(name)
    File.read(File.join(FIXTURES_DIR, "#{name}.html"))
  end

  def body_of(html)
    html[/<body[^>]*>(.*)<\/body>/m, 1].strip
  end

  def test_wrapper_and_section_apply_border_radius_overflow_and_separate_border_collapse
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-wrapper border="1px solid red" border-radius="10px">
            <mj-section>
              <mj-column>
                <mj-text font-size="20px" color="#F45E43" font-family="helvetica">Hello World</mj-text>
              </mj-column>
            </mj-section>
          </mj-wrapper>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("border_radius_overflow"), body_of(result.html)
  end

  def test_wrapper_gap_applies_spacing_between_child_sections
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-wrapper gap="24px">
            <mj-section css-class="first-section">
              <mj-column>
                <mj-text>First</mj-text>
              </mj-column>
            </mj-section>
            <mj-section css-class="second-section">
              <mj-column>
                <mj-text>Second</mj-text>
              </mj-column>
            </mj-section>
          </mj-wrapper>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("gap_spacing"), body_of(result.html)
  end

  def test_wrapper_renders_background_url_styles
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-wrapper background-url="https://example.com/bg.jpg" background-color="#ffffff" background-size="cover" background-repeat="no-repeat">
            <mj-section>
              <mj-column>
                <mj-text>Hello</mj-text>
              </mj-column>
            </mj-section>
          </mj-wrapper>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("background_url_styles"), body_of(result.html)
  end

  def test_wrapper_renders_vml_for_background_url
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-wrapper background-url="https://example.com/bg.jpg" background-color="#cccccc">
            <mj-section>
              <mj-column>
                <mj-text>Hello</mj-text>
              </mj-column>
            </mj-section>
          </mj-wrapper>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("vml_background_url"), body_of(result.html)
  end

  def test_wrapper_background_vml_matches_upstream_outlook_width_and_fill_format
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-wrapper
            background-url="https://example.com/bg.jpg"
            background-color="#cccccc"
            background-repeat="repeat"
            background-size="contain"
            background-position="left top"
          >
            <mj-section>
              <mj-column>
                <mj-text>Hello</mj-text>
              </mj-column>
            </mj-section>
          </mj-wrapper>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("vml_upstream_format"), body_of(result.html)
  end

  def test_wrapper_full_width_with_background_url
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-wrapper full-width="full-width" background-url="https://example.com/bg.jpg" background-color="#ffffff" css-class="hero">
            <mj-section>
              <mj-column>
                <mj-text>Hello</mj-text>
              </mj-column>
            </mj-section>
          </mj-wrapper>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("full_width_background_url"), body_of(result.html)
  end

  def test_full_width_wrapper_keeps_inner_max_width_for_standard_child_sections
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-wrapper full-width="full-width" background-color="#101e3c">
            <mj-section background-color="#ffffff" padding-left="15px" padding-right="15px">
              <mj-column width="70%">
                <mj-text>Hello</mj-text>
              </mj-column>
            </mj-section>
          </mj-wrapper>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("full_width_inner_max_width"), body_of(result.html)
  end

  def test_full_width_wrapper_forces_child_full_width_sections_back_to_standard_width
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-wrapper full-width="full-width" background-color="#f0f0f0">
            <mj-section full-width="full-width" css-class="inner-full">
              <mj-column>
                <mj-text>Hello</mj-text>
              </mj-column>
            </mj-section>
          </mj-wrapper>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("full_width_forces_standard"), body_of(result.html)
  end

  def test_wrapper_without_background_url_has_no_vml_or_inner_div
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-wrapper background-color="#f0f0f0">
            <mj-section>
              <mj-column>
                <mj-text>Hello</mj-text>
              </mj-column>
            </mj-section>
          </mj-wrapper>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("no_background_url"), body_of(result.html)
  end

  def test_wrapper_accepts_full_width_in_strict_mode
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-wrapper full-width="full-width" background-color="#f0f0f0" css-class="hero-wrap">
            <mj-section>
              <mj-column>
                <mj-text>Wrapped</mj-text>
              </mj-column>
            </mj-section>
          </mj-wrapper>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("full_width_strict"), body_of(result.html)
  end

  # Each wrapper child section gets its own Outlook <tr><td>, not all in one <tr>.
  def test_wrapper_children_each_get_own_outlook_tr
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-wrapper>
            <mj-section><mj-column><mj-text>A</mj-text></mj-column></mj-section>
            <mj-section><mj-column><mj-text>B</mj-text></mj-column></mj-section>
          </mj-wrapper>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("children_outlook_tr"), body_of(result.html)
  end

  # Wrapper child Outlook td should carry suffixed css-class.
  def test_wrapper_child_outlook_td_suffixes_css_class
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-wrapper>
            <mj-section css-class="inner hero">
              <mj-column><mj-text>Hello</mj-text></mj-column>
            </mj-section>
          </mj-wrapper>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("child_outlook_css_class"), body_of(result.html)
  end

  # Wrapper with gap should omit bgcolor from Outlook before table on child sections.
  def test_wrapper_gap_omits_bgcolor_from_outlook_before
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-wrapper gap="20px">
            <mj-section background-color="#ff0000">
              <mj-column><mj-text>Red</mj-text></mj-column>
            </mj-section>
            <mj-section background-color="#00ff00">
              <mj-column><mj-text>Green</mj-text></mj-column>
            </mj-section>
          </mj-wrapper>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("gap_omits_bgcolor"), body_of(result.html)
  end
end
