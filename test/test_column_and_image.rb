require "minitest/autorun"

require_relative "../lib/mjml-rb"

class TestColumnAndImage < Minitest::Test
  FIXTURES_DIR = File.join(__dir__, "fixtures/column_and_image")

  def render(mjml)
    html = MjmlRb.mjml2html(mjml).fetch(:html)
    html[/<body[^>]*>(.*)<\/body>/m, 1].strip
  end

  def expected(name)
    File.read(File.join(FIXTURES_DIR, "#{name}.html"))
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

    assert_equal expected("image_in_half_width_column"), html
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

    assert_equal expected("column_padding_reduces_image_width"), html
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

    assert_equal expected("image_href_escaped"), html
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

    assert_equal expected("image_border_radius"), html
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

    assert_equal expected("image_dimension_attributes"), html
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

    assert_equal expected("fluid_on_mobile"), html
  end
end
