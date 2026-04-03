require "minitest/autorun"

require_relative "../lib/mjml-rb"

class ColumnTest < Minitest::Test
  FIXTURES_DIR = File.join(__dir__, "fixtures/column")

  def render(mjml)
    MjmlRb.mjml2html(mjml).fetch(:html)
  end

  def expected(name)
    File.read(File.join(FIXTURES_DIR, "#{name}.html"))
  end

  def test_section_horizontal_padding_reduces_column_child_container_width
    html = render(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section padding="0 20px">
            <mj-column padding="0">
              <mj-image src="https://example.com/img.jpg" alt="" padding="0" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_equal expected("section_horizontal_padding"), html
  end

  def test_outlook_td_carries_suffixed_css_class
    html = render(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column css-class="col-hero extra">
              <mj-text>Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_equal expected("outlook_css_class"), html
  end

  def test_px_width_column_generates_px_class_and_media_query
    html = render(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column width="200px" padding="0">
              <mj-text>Narrow</mj-text>
            </mj-column>
            <mj-column padding="0">
              <mj-text>Fill</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_equal expected("px_width"), html
  end

  def test_pct_width_column_generates_per_class_and_media_query
    html = render(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column width="40%">
              <mj-text>Left</mj-text>
            </mj-column>
            <mj-column width="60%">
              <mj-text>Right</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_equal expected("pct_width"), html
  end

  def test_column_border_radius_matches_mjml_port_case
    html = render(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column border-radius="50px" inner-border-radius="40px" padding="50px" border="5px solid #000" inner-border="5px solid #666">
              <mj-text>Hello World</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_equal expected("border_radius"), html
  end
end
