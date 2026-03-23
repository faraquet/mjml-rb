require "minitest/autorun"
require "nokogiri"

require_relative "../lib/mjml-rb"

class MJMLStyleInlineTest < Minitest::Test
  def test_mj_style_inline_applies_class_rules_to_rendered_markup
    mjml = <<~MJML
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

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    assert_empty(result.errors)
    assert_includes(result.html, 'class="mail-body"')
    assert_includes(result.html, 'background-color: #f5f5f5')
    assert_includes(result.html, 'padding-top: 10px')
    refute_includes(result.html, '.app-bnr > table > tbody > tr > td { background-color: #e0f5f3; padding-left: 15px; padding-right: 15px; }')
    assert_includes(result.html, 'class="app-bnr radius--top radius--bottom"')
    assert_includes(result.html, 'border-top-left-radius: 8px')
    assert_includes(result.html, 'border-bottom-right-radius: 8px')
    assert_includes(result.html, 'background-color: #e0f5f3')
    assert_includes(result.html, 'padding-left: 15px')
    assert_includes(result.html, 'padding-right: 15px')
    assert_includes(result.html, 'class="padding--none--this"')
    assert_includes(result.html, 'padding: 0')
    assert_includes(result.html, 'class="padding--top--s--this"')
    assert_includes(result.html, 'padding-top: 10px')
    assert_includes(result.html, 'class="app-bnr--download-buttons"')
    assert_includes(result.html, 'display: none')
  end

  def test_mj_style_inline_supports_lang_pseudo_selector
    mjml = <<~MJML
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

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    assert_empty(result.errors)

    document = Nokogiri::HTML(result.html)
    styles = document.css(".caps").map { |node| node["style"].to_s }
    assert(styles.any? { |style| style.include?("text-transform: uppercase") })
    assert(styles.any? { |style| style.include?("letter-spacing: 2px") })
  end

  def test_mj_style_inline_uses_important_for_precedence_without_serializing_it
    mjml = <<~MJML
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

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    assert_empty(result.errors)

    document = Nokogiri::HTML(result.html)
    style = document.at_css(".card--header--content a")["style"].to_s

    assert_includes(style, "display: inline")
    assert_includes(style, "width: 100%")
    refute_includes(style, "display: block")
    refute_includes(style, "!important")
  end

  def test_mj_style_inline_does_not_preserve_at_media_rules
    mjml = <<~MJML
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

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    assert_empty(result.errors)

    refute_includes(result.html, "@media (max-width: 600px)")
    refute_includes(result.html, ".mobile-hide")
    assert_includes(result.html, "color: red")
  end

  def test_mj_style_inline_does_not_preserve_at_font_face_rules
    mjml = <<~MJML
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

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    assert_empty(result.errors)

    refute_includes(result.html, "@font-face")
    refute_includes(result.html, "woff2")

    document = Nokogiri::HTML(result.html)
    styles = document.css(".custom").map { |node| node["style"].to_s }
    assert(styles.any? { |style| style.include?("font-family: 'CustomFont', sans-serif") })
  end

  def test_mj_style_inline_higher_specificity_wins
    mjml = <<~MJML
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

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    assert_empty(result.errors)

    # .container .item (specificity 0,2,0) should beat .item (specificity 0,1,0)
    # even though .item appears later in the CSS source
    document = Nokogiri::HTML(result.html)
    item_nodes = document.css(".item")
    styles = item_nodes.map { |n| n["style"].to_s }
    assert(styles.any? { |style| style.include?("color: red") },
           "Expected .container .item (higher specificity) to win over .item")
  end

  def test_mj_style_inline_keeps_latest_declaration_order_for_overwritten_properties
    mjml = <<~MJML
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

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    assert_empty(result.errors)

    document = Nokogiri::HTML(result.html)
    style = document.at_css("td.target")["style"].to_s

    assert_includes(style, "padding-bottom: 0")
    assert_includes(style, "padding: 0 0 10px")
    assert_operator(style.index("padding-bottom: 0"), :<, style.index("padding: 0 0 10px"))
    refute_includes(style, "!important")
  end

  def test_mj_style_inline_serializes_padding_shorthand_before_padding_bottom_override
    mjml = <<~MJML
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

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    assert_empty(result.errors)

    document = Nokogiri::HTML(result.html)
    style = document.at_css("td.target")["style"].to_s

    assert_operator(style.index("padding: 3px 10px"), :<, style.index("padding-bottom: 0"))
  end

  def test_inline_css_preserves_gradient_background_image_on_non_button_content
    mjml = <<~MJML
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

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    assert_empty(result.errors)

    document = Nokogiri::HTML(result.html)
    node = document.at_css(".gradient + div") || document.at_css(".gradient")

    if node.nil? || !node["style"].to_s.include?("background-image")
      node = document.css("div").find do |el|
        el["style"].to_s.include?("background-image: linear-gradient")
      end
    end

    refute_nil(node)

    style = node["style"].to_s
    assert_includes(style, "background-color: #00ada5")
    assert_includes(style, "background-image: linear-gradient(to bottom, #00ada5, #009089)")
    refute_match(/background:\s*#00ada5/i, style)
  end

  def test_inline_css_keeps_background_attribute_sync_for_url_background_images
    mjml = <<~MJML
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

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    assert_empty(result.errors)

    document = Nokogiri::HTML(result.html)
    cell = document.at_css(".with-bg td[background='https://example.com/bg.png']")
    refute_nil(cell)
    assert_equal("#00ada5", cell["bgcolor"])
    assert_includes(cell["style"].to_s, "background-image: url(https://example.com/bg.png)")
    refute_match(/background:\s*#00ada5/i, cell["style"].to_s)
  end

  def test_inline_css_does_not_overwrite_existing_background_shorthand
    mjml = <<~MJML
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

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    assert_empty(result.errors)

    document = Nokogiri::HTML(result.html)
    button_cell = document.at_css("td[bgcolor='white']")
    refute_nil(button_cell)
    assert_includes(button_cell["style"].to_s, "background: #414141")
    assert_includes(button_cell["style"].to_s, "background-color: white")

    button_link = document.at_css("td[bgcolor='white'] a")
    refute_nil(button_link)
    assert_includes(button_link["style"].to_s, "background: #414141")
    assert_includes(button_link["style"].to_s, "background-color: white")
  end

  # ── HTML attribute syncing (Juice parity) ──────────────────────────────

  def test_inline_css_syncs_width_and_height_on_img
    mjml = <<~MJML
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

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    assert_empty(result.errors)

    document = Nokogiri::HTML(result.html)
    img = document.at_css("img[src='logo.png']")
    refute_nil(img, "Expected to find img with src=logo.png")

    assert_equal("auto", img["width"], "CSS width: auto should sync to HTML width attribute")
    assert_equal("24", img["height"], "CSS height: 24px should sync to HTML height attribute (without px)")
  end

  def test_inline_css_does_not_sync_width_percentage_on_img
    mjml = <<~MJML
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

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    assert_empty(result.errors)

    document = Nokogiri::HTML(result.html)
    img = document.at_css("img[src='photo.jpg']")
    refute_nil(img)

    assert_equal("200", img["width"], "CSS width: 100% should remain in CSS and keep the existing pixel width attribute")
    assert_includes(img["style"].to_s, "width: 100%")
  end

  def test_inline_css_does_not_rewrite_img_width_attribute_when_width_was_not_inlined
    mjml = <<~MJML
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

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    assert_empty(result.errors)

    document = Nokogiri::HTML(result.html)
    img = document.at_css("img[src='photo.jpg']")
    refute_nil(img)

    assert_equal("200", img["width"], "Unrelated inlined CSS should not overwrite mj-image width attribute")
  end

  def test_inline_css_syncs_bgcolor_on_td
    mjml = <<~MJML
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

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    assert_empty(result.errors)

    document = Nokogiri::HTML(result.html)
    tds_with_bgcolor = document.css("td[bgcolor='#ff0000']")
    refute_empty(tds_with_bgcolor, "Expected td elements to get bgcolor attribute from inlined background-color")
  end

  def test_inline_css_syncs_align_on_td
    mjml = <<~MJML
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

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    assert_empty(result.errors)

    document = Nokogiri::HTML(result.html)
    tds_with_align = document.css("td[align='right']")
    refute_empty(tds_with_align, "Expected td elements to get align attribute from inlined text-align")
  end

  def test_inline_css_syncs_valign_on_td
    mjml = <<~MJML
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

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    assert_empty(result.errors)

    document = Nokogiri::HTML(result.html)
    tds_with_valign = document.css("td[valign='top']")
    refute_empty(tds_with_valign, "Expected td elements to get valign attribute from inlined vertical-align")
  end

  def test_inline_css_syncs_width_on_table
    mjml = <<~MJML
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

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    assert_empty(result.errors)

    document = Nokogiri::HTML(result.html)
    tables = document.css(".fixed-table table[width='400']")
    refute_empty(tables, "Expected table to get width=400 from inlined width: 400px (px stripped)")
  end

  def test_inline_css_does_not_sync_bgcolor_for_transparent
    mjml = <<~MJML
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

    result = MjmlRb::Compiler.new(validation_level: "strict").compile(mjml)
    assert_empty(result.errors)

    document = Nokogiri::HTML(result.html)
    tds_with_bgcolor = document.css(".transparent td[bgcolor]")
    assert_empty(tds_with_bgcolor, "Should not set bgcolor for transparent background-color")
  end
end
