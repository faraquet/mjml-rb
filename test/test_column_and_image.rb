require "minitest/autorun"

require_relative "../lib/mjml-rb"

class TestColumnAndImage < Minitest::Test
  def render(mjml)
    MjmlRb.mjml2html(mjml).fetch(:html)
  end

  def test_image_in_half_width_column_uses_column_container_width
    html = render(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column width="50%" padding="0">
              <mj-image src="https://example.com/photo.jpg" alt="Photo" />
            </mj-column>
            <mj-column width="50%" padding="0">
              <mj-text>Right</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_includes html, 'width="250"'
    refute_includes html, 'width="550"'
  end

  def test_column_padding_reduces_child_image_width
    html = render(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column width="50%" padding="0 10px">
              <mj-image src="https://example.com/photo.jpg" alt="Photo" />
            </mj-column>
            <mj-column width="50%" padding="0">
              <mj-text>Right</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_includes html, 'width="230"'
    refute_includes html, 'width="250"'
  end

  def test_image_href_is_escaped_once
    html = render(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-image
                src="https://example.com/photo.jpg"
                href="https://example.com/hotel?utm_source=email&utm_medium=transactional"
                alt="Photo"
              />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_includes html, 'href="https://example.com/hotel?utm_source=email&amp;utm_medium=transactional"'
    refute_includes html, "&amp;amp;"
  end

  def test_image_keeps_inline_border_radius_style
    html = render(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-image
                src="https://example.com/photo.jpg"
                alt="Photo"
                border-radius="8px"
                border="0"
              />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_includes html, "border-radius:8px"
    assert_includes html, "display:block"
    assert_includes html, 'width="550"'
  end

  def test_image_emits_cell_and_image_dimension_attributes_like_mjml
    html = render(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column padding="0">
              <mj-image
                src="https://example.com/logo.png"
                alt=""
                align="left"
                width="140px"
                height="24px"
                padding="0"
              />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_includes html, '<td style="width:140px" width="140" height="24" align="left">'
    assert_includes html, 'style="border:0;display:block;outline:none;text-decoration:none;height:24px;width:100%;font-size:13px"'
    assert_includes html, 'src="https://example.com/logo.png"'
    assert_includes html, 'width="auto"'
    assert_includes html, 'height="24"'
  end

  def test_image_supports_fluid_on_mobile_and_passthrough_source_attributes
    html = render(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-image
                src="https://example.com/photo.jpg"
                alt="Photo"
                fluid-on-mobile="true"
                usemap="#promo-map"
                srcset="https://example.com/photo.jpg 1x, https://example.com/photo@2x.jpg 2x"
                sizes="100vw"
              />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_includes html, "table.mj-full-width-mobile { width: 100% !important; }"
    assert_includes html, "td.mj-full-width-mobile { width: auto !important; }"
    assert_includes html, 'class="mj-full-width-mobile"'
    assert_includes html, 'usemap="#promo-map"'
    assert_includes html, 'srcset="https://example.com/photo.jpg 1x, https://example.com/photo@2x.jpg 2x"'
    assert_includes html, 'sizes="100vw"'
  end
end
