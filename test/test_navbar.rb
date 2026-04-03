require "minitest/autorun"
require "securerandom"

require_relative "../lib/mjml-rb"

class NavbarTest < Minitest::Test
  FIXTURES_DIR = File.join(__dir__, "fixtures/navbar")
  FIXED_ID = "0123456789abcdef"

  def render_with_fixed_id(mjml)
    original_hex = SecureRandom.method(:hex)
    SecureRandom.define_singleton_method(:hex) { |_length = nil| FIXED_ID }
    MjmlRb.mjml2html(mjml).fetch(:html)
  ensure
    SecureRandom.define_singleton_method(:hex, original_hex)
  end

  def expected(name)
    File.read(File.join(FIXTURES_DIR, "#{name}.html"))
  end

  def test_navbar_hamburger_icon_padding_matches_mjml_port_case
    html = render_with_fixed_id(<<~MJML)
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

    assert_equal expected("hamburger_icon_padding"), html
  end

  def test_navbar_component_renders_links_with_base_url_and_outlook_markup
    html = render_with_fixed_id(<<~MJML)
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

    assert_equal expected("links_with_base_url"), html
  end

  def test_navbar_component_renders_hamburger_markup_and_uses_breakpoint_for_head_style
    html = render_with_fixed_id(<<~MJML)
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

    assert_equal expected("hamburger_with_breakpoint"), html
  end
end
