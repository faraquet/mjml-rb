require "minitest/autorun"

require_relative "../lib/mjml-rb"

class ButtonTest < Minitest::Test
  FIXTURES_DIR = File.join(__dir__, "fixtures/button")

  def compile(mjml, **opts)
    MjmlRb::Compiler.new(**opts).compile(mjml)
  end

  def expected(name)
    File.read(File.join(FIXTURES_DIR, "#{name}.html"))
  end

  def test_button_component_renders_with_href
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-button href="https://example.com">Click me</mj-button>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, expected("renders_with_href")
  end

  def test_button_href_query_params_are_escaped_once
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-button href="https://example.com/booking?utm_source=email&utm_medium=transactional&amp;utm_campaign=spring">
                Manage booking
              </mj-button>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, expected("href_query_params_escaped")
  end

  def test_button_component_renders_without_href_as_p_tag
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-button>No link</mj-button>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, expected("without_href_as_p_tag")
  end

  def test_button_component_respects_custom_attributes
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-button href="https://example.com"
                background-color="#ff0000"
                color="#000000"
                font-size="16px"
                border-radius="8px"
                inner-padding="15px 30px"
                padding="20px 30px"
                target="_self">Buy Now</mj-button>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, expected("custom_attributes")
  end

  def test_button_inlined_background_color_preserves_existing_background_shorthand
    result = compile(<<~MJML)
      <mjml>
        <mj-head>
          <mj-style inline="inline">
            .btn table td {
              background-color: white;
              border: 1px solid #e6e6e6;
            }

            .btn a {
              background-color: white;
              color: #00ada5;
            }
          </mj-style>
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-button css-class="btn" href="https://example.com">Manage your booking</mj-button>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, expected("inlined_background_color")
  end

  def test_button_inlined_gradient_preserves_background_image
    result = compile(<<~MJML)
      <mjml>
        <mj-head>
          <mj-style inline="inline">
            .btn a {
              background-color: #00ada5;
              background-image: linear-gradient(to bottom, #00ada5, #009089);
              color: white;
            }
          </mj-style>
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-button css-class="btn" background-color="#00ada5" href="https://example.com">
                Book your stay
              </mj-button>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, expected("inlined_gradient")
  end
end
