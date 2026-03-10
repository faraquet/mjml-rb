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
end
