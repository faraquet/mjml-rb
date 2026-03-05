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
end
