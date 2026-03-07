require "minitest/autorun"
require "nokogiri"

require_relative "../lib/mjml-rb"

class ColumnTest < Minitest::Test
  def render(mjml)
    MjmlRb.mjml2html(mjml).fetch(:html)
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
