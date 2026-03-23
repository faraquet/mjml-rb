require "minitest/autorun"
require "nokogiri"

require_relative "../lib/mjml-rb"

class ButtonTest < Minitest::Test
  def compile(mjml, **opts)
    MjmlRb::Compiler.new(**opts).compile(mjml)
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

    assert_empty(result.errors)
    # Outer wrapper
    assert_includes(result.html, 'align="center"')
    assert_includes(result.html, 'word-break:break-word')
    # Inner button table
    assert_includes(result.html, 'border-collapse:separate')
    assert_includes(result.html, 'line-height:100%')
    # Inner td with bgcolor
    assert_includes(result.html, 'bgcolor="#414141"')
    assert_includes(result.html, 'border-radius:3px')
    assert_includes(result.html, 'cursor:auto')
    assert_includes(result.html, 'mso-padding-alt:10px 25px')
    # Link
    assert_includes(result.html, 'href="https://example.com"')
    assert_includes(result.html, 'target="_blank"')
    assert_includes(result.html, 'display:inline-block')
    assert_includes(result.html, 'mso-padding-alt:0px')
    assert_includes(result.html, 'Click me')
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

    assert_empty(result.errors)
    assert_includes(
      result.html,
      'href="https://example.com/booking?utm_source=email&amp;utm_medium=transactional&amp;utm_campaign=spring"'
    )
    refute_includes(result.html, "&amp;amp;")
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

    assert_empty(result.errors)
    assert_includes(result.html, '<p ')
    refute_includes(result.html, '<a ')
    assert_includes(result.html, 'No link')
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

    assert_empty(result.errors)
    assert_includes(result.html, 'bgcolor="#ff0000"')
    assert_includes(result.html, 'background:#ff0000')
    assert_includes(result.html, 'color:#000000')
    assert_includes(result.html, 'font-size:16px')
    assert_includes(result.html, 'border-radius:8px')
    assert_includes(result.html, 'padding:15px 30px')
    assert_includes(result.html, 'target="_self"')
    assert_includes(result.html, 'Buy Now')
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

    assert_empty(result.errors)
    assert_includes(result.html, 'bgcolor="white"')
    assert_includes(result.html, 'background-color: white')
    refute_includes(result.html, 'bgcolor="#414141"')
    assert_includes(result.html, 'background: #414141')
    refute_includes(result.html, 'background: white')
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

    assert_empty(result.errors)

    document = Nokogiri::HTML(result.html)
    link = document.at_css('a[href="https://example.com"]')
    refute_nil(link)

    style = link["style"].to_s
    assert_includes(style, "background: #00ada5")
    assert_includes(style, "background-color: #00ada5")
    assert_includes(style, "background-image: linear-gradient(to bottom, #00ada5, #009089)")
  end
end
