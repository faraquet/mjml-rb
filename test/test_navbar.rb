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

  def test_navbar_component_renders_links_with_base_url_and_outlook_markup
    html = render(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-navbar base-url="https://example.com" align="left">
                <mj-navbar-link href="/docs" css-class="nav-link">Docs</mj-navbar-link>
                <mj-navbar-link href="/pricing">Pricing</mj-navbar-link>
              </mj-navbar>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_includes(html, 'class="mj-inline-links"')
    assert_includes(html, 'align="left"')
    assert_includes(html, 'href="https://example.com/docs"')
    assert_includes(html, 'href="https://example.com/pricing"')
    assert_includes(html, 'class="mj-link nav-link"')
    assert_includes(html, 'class="nav-link-outlook"')
    assert_includes(html, 'text-transform:uppercase')
  end

  def test_navbar_component_renders_hamburger_markup_and_uses_breakpoint_for_head_style
    html = render(<<~MJML)
      <mjml>
        <mj-head>
          <mj-breakpoint width="320px" />
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-navbar
                hamburger="hamburger"
                ico-color="#ffffff"
                ico-padding="20px"
                ico-padding-top="50px"
                ico-padding-right="40px"
                ico-padding-bottom="20px"
                ico-padding-left="30px"
              >
                <mj-navbar-link href="/docs">Docs</mj-navbar-link>
              </mj-navbar>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_includes(html, '@media only screen and (max-width:319px)')
    assert_includes(html, 'class="mj-menu-checkbox"')
    assert_includes(html, 'class="mj-menu-trigger"')
    assert_includes(html, 'class="mj-menu-label"')
    assert_includes(html, 'color:#ffffff')
    assert_includes(html, 'padding-top:50px')
    assert_includes(html, 'padding-right:40px')
    assert_includes(html, 'padding-bottom:20px')
    assert_includes(html, 'padding-left:30px')
  end

  private

  def extract_style_value(style, property)
    styles = style.to_s.split(";").map(&:strip).reject(&:empty?)
    entry = styles.find { |item| item.start_with?("#{property}:") }
    entry&.split(":", 2)&.last&.strip
  end
end
