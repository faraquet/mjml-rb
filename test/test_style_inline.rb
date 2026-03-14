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

  def test_mj_style_inline_preserves_important_declarations
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

    assert_includes(style, "display: inline !important")
    assert_includes(style, "width: 100%")
    refute_includes(style, "display: block")
  end

  def test_mj_style_inline_preserves_at_media_rules
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

    # The @media rule should be preserved as a <style> block in the document
    assert_includes(result.html, "@media (max-width: 600px)")
    assert_includes(result.html, ".mobile-hide")
    assert_includes(result.html, "display: none !important")

    # The regular rule should still be inlined
    assert_includes(result.html, "color: red")
  end

  def test_mj_style_inline_preserves_at_font_face_rules
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

    # @font-face should be preserved in a <style> block
    assert_includes(result.html, "@font-face")
    assert_includes(result.html, "CustomFont")
    assert_includes(result.html, "woff2")

    # The class rule should still be inlined
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
    assert_includes(style, "padding: 0 0 10px !important")
    assert_operator(style.index("padding-bottom: 0"), :<, style.index("padding: 0 0 10px !important"))
  end
end
