require "minitest/autorun"
require "nokogiri"

require_relative "../lib/mjml-rb"

class ColumnTest < Minitest::Test
  def render(mjml)
    MjmlRb.mjml2html(mjml).fetch(:html)
  end

  # Section horizontal padding should reduce the container width seen by
  # columns, matching npm section's getChildContext() behavior.
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

    # Body default is 600px.  Section padding-left:20 + padding-right:20
    # reduces box to 560px.  Single column at 100% → child container = 560.
    # Image with padding 0 should get width="560" on the <img> tag.
    assert_includes html, '<img alt="" src="https://example.com/img.jpg"'
    assert_includes html, 'width="560" height="auto" />'
  end

  # The Outlook conditional <td> wrapping each column should carry the
  # column's css-class with an "-outlook" suffix, matching npm behavior.
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

    assert_includes html, 'class="col-hero-outlook extra-outlook"'
  end

  # Columns with explicit pixel width should generate mj-column-px-{value}
  # class names and px-based media queries, matching npm getColumnClass().
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

    # px column gets mj-column-px-200 class
    assert_includes html, 'class="mj-column-px-200 mj-outlook-group-fix"'
    # px-based media query rule
    assert_includes html, ".mj-column-px-200 { width:200px !important; max-width: 200px; }"
    # Outlook td uses raw 200px width
    assert_includes html, "width:200px;"
  end

  # Columns with percentage width should still generate mj-column-per-{value}
  # class names and percentage-based media queries.
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

    assert_includes html, 'class="mj-column-per-40 mj-outlook-group-fix"'
    assert_includes html, 'class="mj-column-per-60 mj-outlook-group-fix"'
    assert_includes html, ".mj-column-per-40 { width:40% !important; max-width: 40%; }"
    assert_includes html, ".mj-column-per-60 { width:60% !important; max-width: 60%; }"
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

    document = Nokogiri::HTML(html)
    nodes = document.css(".mj-column-per-100 > table > tbody > tr > td, .mj-column-per-100 > table > tbody > tr > td > table")

    border_radius = nodes.map { |node| extract_style_value(node["style"], "border-radius") }
    border_collapse = nodes.map { |node| extract_style_value(node["style"], "border-collapse") }

    assert_equal(["50px", "40px"], border_radius)
    assert_equal(["separate", "separate"], border_collapse)
  end
  private

  def extract_style_value(style, property)
    styles = style.to_s.split(";").map(&:strip).reject(&:empty?)
    entry = styles.find { |item| item.start_with?("#{property}:") }
    entry&.split(":", 2)&.last&.strip
  end
end
