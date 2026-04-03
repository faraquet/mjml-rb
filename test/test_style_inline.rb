require "minitest/autorun"

require_relative "../lib/mjml-rb"

class MJMLStyleInlineTest < Minitest::Test
  FIXTURES_DIR = File.join(__dir__, "fixtures/style_inline")

  def compile(mjml)
    MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
  end

  def expected(name)
    File.read(File.join(FIXTURES_DIR, "#{name}.html"))
  end

  def test_mj_style_inline_applies_class_rules_to_rendered_markup
    result = compile(<<~MJML)
      <mjml>
        <mj-head>
          <mj-style inline="inline">
            .mail-body { background-color: #f5f5f5; padding-top: 10px; padding-bottom: 10px; }
            .app-bnr > table > tbody > tr > td { background-color: #e0f5f3; padding-left: 15px; padding-right: 15px; }
            .radius--top > table,
            .radius--top > table > tbody > tr > td { border-top-left-radius: 8px; border-top-right-radius: 8px; }
            .radius--bottom > table,
            .radius--bottom > table > tbody > tr > td { border-bottom-left-radius: 8px; border-bottom-right-radius: 8px; }
            .padding--none--this { padding: 0 !important; }
            .padding--top--s--this { padding-top: 10px !important; }
            .app-bnr--download-buttons { display: none; }
          </mj-style>
        </mj-head>
        <mj-body css-class="mail-body">
          <mj-section css-class="app-bnr radius--top radius--bottom">
            <mj-column>
              <mj-table css-class="padding--none--this">
                <tr>
                  <td class="padding--top--s--this">Cell</td>
                </tr>
                <tr>
                  <td class="app-bnr--download-buttons">Buttons</td>
                </tr>
              </mj-table>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("applies_class_rules"), result.html
  end

  def test_mj_style_inline_supports_lang_pseudo_selector
    result = compile(<<~MJML)
      <mjml lang="ar">
        <mj-head>
          <mj-style inline="inline">
            .caps:lang(ar) { text-transform: uppercase; letter-spacing: 2px; }
          </mj-style>
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text css-class="caps">Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("lang_pseudo_selector"), result.html
  end

  def test_mj_style_inline_uses_important_for_precedence_without_serializing_it
    result = compile(<<~MJML)
      <mjml>
        <mj-head>
          <mj-style inline="inline">
            p a { display: inline !important; color: #00ada5 !important; }
            .card--header--content a { display: block; width: 100%; color: #00ada5; text-decoration: none; line-height: 1.3; font-size: 16px; font-weight: 600; }
          </mj-style>
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text css-class="card--header--content">
                <p>Your account has successfully been activated. You can now <a href="https://example.test/sign-in">sign in</a>.</p>
              </mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("important_precedence"), result.html
  end

  def test_mj_style_inline_does_not_preserve_at_media_rules
    result = compile(<<~MJML)
      <mjml>
        <mj-head>
          <mj-style inline="inline">
            @media (max-width: 600px) {
              .mobile-hide { display: none !important; }
            }
            .highlight { color: red; }
          </mj-style>
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text css-class="highlight">Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("no_at_media_rules"), result.html
  end

  def test_mj_style_inline_does_not_preserve_at_font_face_rules
    result = compile(<<~MJML)
      <mjml>
        <mj-head>
          <mj-style inline="inline">
            @font-face {
              font-family: 'CustomFont';
              src: url('https://example.com/custom.woff2') format('woff2');
            }
            .custom { font-family: 'CustomFont', sans-serif; }
          </mj-style>
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text css-class="custom">Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("no_at_font_face_rules"), result.html
  end

  def test_mj_style_inline_higher_specificity_wins
    result = compile(<<~MJML)
      <mjml>
        <mj-head>
          <mj-style inline="inline">
            .container .item { color: red; }
            .item { color: blue; }
          </mj-style>
        </mj-head>
        <mj-body>
          <mj-section css-class="container">
            <mj-column>
              <mj-text css-class="item">Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("higher_specificity_wins"), result.html
  end

  def test_mj_style_inline_keeps_latest_declaration_order_for_overwritten_properties
    result = compile(<<~MJML)
      <mjml>
        <mj-head>
          <mj-style inline="inline">
            .scope td.target { padding: 0 0 10px !important; width: auto !important; }
          </mj-style>
        </mj-head>
        <mj-body>
          <mj-raw>
            <table class="scope">
              <tr>
                <td class="target" style="padding: 5px 0; color: #333; padding-bottom: 0">Cell</td>
              </tr>
            </table>
          </mj-raw>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("declaration_order"), result.html
  end

  def test_mj_style_inline_serializes_padding_shorthand_before_padding_bottom_override
    result = compile(<<~MJML)
      <mjml>
        <mj-head>
          <mj-style inline="inline">
            .padding-bottom-none td.target { padding-bottom: 0 !important; }
            .pricing-summary--table tr td.target { border-top: 1px solid #e6e6e6; padding: 3px 10px; font-size: 14px; }
          </mj-style>
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-table css-class="pricing-summary--table padding-bottom-none">
                <tr><td class="target">Cell</td></tr>
              </mj-table>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("padding_shorthand_before_override"), result.html
  end

  def test_inline_css_preserves_gradient_background_image_on_non_button_content
    result = compile(<<~MJML)
      <mjml>
        <mj-head>
          <mj-style inline="inline">
            .gradient div {
              background-color: #00ada5;
              background-image: linear-gradient(to bottom, #00ada5, #009089);
            }
          </mj-style>
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text css-class="gradient">Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("gradient_background_image"), result.html
  end

  def test_inline_css_keeps_background_attribute_sync_for_url_background_images
    result = compile(<<~MJML)
      <mjml>
        <mj-head>
          <mj-style inline="inline">
            .with-bg td {
              background-color: #00ada5;
              background-image: url(https://example.com/bg.png);
            }
          </mj-style>
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-table css-class="with-bg">
                <tr><td>Cell</td></tr>
              </mj-table>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("url_background_image_sync"), result.html
  end

  def test_inline_css_does_not_overwrite_existing_background_shorthand
    result = compile(<<~MJML)
      <mjml>
        <mj-head>
          <mj-style inline="inline">
            .btn table td,
            .btn table td a {
              background-color: white !important;
              color: #00ada5 !important;
            }
          </mj-style>
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-button css-class="btn" background-color="#414141" href="https://example.com">
                Hello
              </mj-button>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("no_overwrite_background_shorthand"), result.html
  end

  # ── HTML attribute syncing (Juice parity) ──────────────────────────────

  def test_inline_css_syncs_width_and_height_on_img
    result = compile(<<~MJML)
      <mjml>
        <mj-head>
          <mj-style inline="inline">
            .logo img { width: auto !important; height: 24px !important; }
          </mj-style>
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column css-class="logo">
              <mj-image width="140px" src="logo.png" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("syncs_width_height_on_img"), result.html
  end

  def test_inline_css_does_not_sync_width_percentage_on_img
    result = compile(<<~MJML)
      <mjml>
        <mj-head>
          <mj-style inline="inline">
            .full img { width: 100% !important; }
          </mj-style>
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column css-class="full">
              <mj-image width="200px" src="photo.jpg" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("no_sync_width_percentage_on_img"), result.html
  end

  def test_inline_css_does_not_rewrite_img_width_attribute_when_width_was_not_inlined
    result = compile(<<~MJML)
      <mjml>
        <mj-head>
          <mj-style inline="inline">
            * { font-family: Arial !important; }
          </mj-style>
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-image width="200px" src="photo.jpg" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("no_rewrite_img_width_when_not_inlined"), result.html
  end

  def test_inline_css_does_not_override_existing_inline_img_width
    result = compile(<<~MJML)
      <mjml>
        <mj-head>
          <mj-style inline="inline">
            .main-message img { width: 30px; display: inline-block; }
          </mj-style>
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text css-class="main-message">
                <p><img src="icon.png" style="width: 15px; height: 15px;" />Confirmed</p>
              </mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("no_override_existing_inline_img_width"), result.html
  end

  def test_inline_css_syncs_bgcolor_on_td
    result = compile(<<~MJML)
      <mjml>
        <mj-head>
          <mj-style inline="inline">
            .highlight td { background-color: #ff0000 !important; }
          </mj-style>
        </mj-head>
        <mj-body>
          <mj-section css-class="highlight">
            <mj-column>
              <mj-text>Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("syncs_bgcolor_on_td"), result.html
  end

  def test_inline_css_syncs_align_on_td
    result = compile(<<~MJML)
      <mjml>
        <mj-head>
          <mj-style inline="inline">
            .right-align td { text-align: right !important; }
          </mj-style>
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-table css-class="right-align">
                <tr><td>Value</td></tr>
              </mj-table>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("syncs_align_on_td"), result.html
  end

  def test_inline_css_syncs_valign_on_td
    result = compile(<<~MJML)
      <mjml>
        <mj-head>
          <mj-style inline="inline">
            .top-align td { vertical-align: top !important; }
          </mj-style>
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-table css-class="top-align">
                <tr><td>Value</td></tr>
              </mj-table>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("syncs_valign_on_td"), result.html
  end

  def test_inline_css_syncs_width_on_table
    result = compile(<<~MJML)
      <mjml>
        <mj-head>
          <mj-style inline="inline">
            .fixed-table table { width: 400px !important; }
          </mj-style>
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-table css-class="fixed-table">
                <tr><td>Cell</td></tr>
              </mj-table>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("syncs_width_on_table"), result.html
  end

  def test_inline_css_does_not_sync_bgcolor_for_transparent
    result = compile(<<~MJML)
      <mjml>
        <mj-head>
          <mj-style inline="inline">
            .transparent td { background-color: transparent !important; }
          </mj-style>
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-table css-class="transparent">
                <tr><td>Cell</td></tr>
              </mj-table>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("no_sync_bgcolor_for_transparent"), result.html
  end
end
