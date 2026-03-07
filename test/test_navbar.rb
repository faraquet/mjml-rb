require "minitest/autorun"
require "nokogiri"

require_relative "../lib/mjml-rb"

class NavbarTest < Minitest::Test
  def render(mjml)
    MjmlRb.mjml2html(mjml).fetch(:html)
  end

  def test_navbar_hamburger_icon_padding_matches_mjml_port_case
    html = render(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-navbar hamburger="hamburger" ico-padding="20px" ico-padding-bottom="20px" ico-padding-left="30px" ico-padding-right="40px" ico-padding-top="50px">
                <mj-navbar-link href="/gettings-started-onboard" color="#ffffff">Getting started</mj-navbar-link>
                <mj-navbar-link href="/try-it-live" color="#ffffff">Try it live</mj-navbar-link>
              </mj-navbar>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    document = Nokogiri::HTML(html)
    labels = document.css(".mj-menu-label")

    assert_equal(["20px"], labels.map { |node| extract_style_value(node["style"], "padding-bottom") })
    assert_equal(["30px"], labels.map { |node| extract_style_value(node["style"], "padding-left") })
    assert_equal(["40px"], labels.map { |node| extract_style_value(node["style"], "padding-right") })
    assert_equal(["50px"], labels.map { |node| extract_style_value(node["style"], "padding-top") })
  end

  private

  def extract_style_value(style, property)
    styles = style.to_s.split(";").map(&:strip).reject(&:empty?)
    entry = styles.find { |item| item.start_with?("#{property}:") }
    entry&.split(":", 2)&.last&.strip
  end
end
