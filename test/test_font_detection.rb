require "minitest/autorun"
require_relative "../lib/mjml-rb"

class FontDetectionTest < Minitest::Test
  def setup
    @renderer = MjmlRb::Renderer.new
  end

  def test_detects_multiple_fonts_with_case_and_line_breaks
    html = font_tags(<<~HTML, "Open Sans", "Ubuntu", "Lato")
      <div style="FONT-FAMILY:
        'open sans', sans-serif">Hello</div>
      <div style="font-family:Ubuntu">World</div>
    HTML

    assert_includes html, font_url("Open Sans")
    assert_includes html, font_url("Ubuntu")
    refute_includes html, font_url("Lato")
  end

  def test_font_names_are_matched_literally
    html = font_tags('<div style="font-family:Noto Sans (Arabic), Mono+One"></div>',
                     "Noto Sans (Arabic)", "Mono+One", "Mono.One")

    assert_includes html, font_url("Noto Sans (Arabic)")
    assert_includes html, font_url("Mono+One")
    refute_includes html, font_url("Mono.One")
  end

  def test_font_name_must_follow_font_family_in_the_same_quoted_span
    html = font_tags(<<~HTML, "Lato", "Roboto", "Ubuntu")
      <div title="Lato" style="font-family:Arial">Roboto</div>
      <div title="Ubuntu;font-family:Arial"></div>
    HTML

    assert_empty html
  end

  def test_requires_quotes_around_content_font_declarations
    [
      'font-family:Lato',
      'font-family:Lato"',
      '"font-family:Lato'
    ].each do |content|
      assert_empty font_tags(content, "Lato")
    end
  end

  def test_preserves_font_detection_between_adjacent_attributes
    html = font_tags('<div data-note="" font-family:Lato data-other=""></div>', "Lato")

    assert_includes html, font_url("Lato")
  end

  def test_checks_inline_css_and_preserves_declaration_boundaries
    html = font_tags("", "Lato", "Roboto", "Ubuntu", "Open Sans", inline_styles: [
      ".text { font-family:Lato, sans-serif; }",
      ".other { FONT-FAMILY:Roboto; color:Ubuntu; } .open-sans { color:red; }"
    ])

    assert_includes html, font_url("Lato")
    assert_includes html, font_url("Roboto")
    refute_includes html, font_url("Ubuntu")
    refute_includes html, font_url("Open Sans")
  end

  def test_deduplicates_urls_and_ignores_empty_font_configuration
    fonts = {
      "Lato" => "https://fonts.example.test/shared.css",
      "Roboto" => "https://fonts.example.test/shared.css",
      "Ubuntu" => nil,
      "Open Sans" => "",
      nil => "https://fonts.example.test/invalid.css",
      "" => "https://fonts.example.test/invalid.css"
    }
    html = @renderer.send(:build_font_tags, '<div style="font-family:Lato,Roboto,Ubuntu,Open Sans"></div>', [], fonts)

    assert_equal 1, html.scan(/<link /).size
    assert_equal 1, html.scan(/@import /).size
    refute_includes html, "invalid.css"
  end

  def test_skips_detection_when_no_fonts_are_configured
    [nil, {}].each do |fonts|
      assert_font_detection_skipped(fonts)
    end
  end

  def test_skips_detection_when_all_font_urls_are_disabled
    [nil, ""].each do |url|
      assert_font_detection_skipped(MjmlRb::Renderer::DEFAULT_FONTS.transform_values { url })
    end
    assert_font_detection_skipped("Lato" => nil, "Roboto" => "")
  end

  def test_skips_detection_when_all_font_names_are_empty
    assert_font_detection_skipped(nil => font_url("Lato"), "" => font_url("Roboto"))
  end

  def test_reused_renderer_picks_up_changed_fonts
    parser = MjmlRb::Parser.new
    source = '<mjml><mj-body><mj-section><mj-column><mj-text font-family="%s">Hello</mj-text></mj-column></mj-section></mj-body></mjml>'
    first = @renderer.render(parser.parse(source % "Lato"))
    second = @renderer.render(parser.parse(source % "Roboto"))

    assert_includes first, MjmlRb::Renderer::DEFAULT_FONTS.fetch("Lato")
    refute_includes first, MjmlRb::Renderer::DEFAULT_FONTS.fetch("Roboto")
    assert_includes second, MjmlRb::Renderer::DEFAULT_FONTS.fetch("Roboto")
    refute_includes second, MjmlRb::Renderer::DEFAULT_FONTS.fetch("Lato")
  end

  private

  def assert_font_detection_skipped(fonts)
    content = +'<div style="font-family:Lato,Roboto"></div>'
    content.define_singleton_method(:scan) do |*|
      raise "Font declarations must not be scanned when no font URL can be emitted"
    end

    assert_empty @renderer.send(:build_font_tags, content, [], fonts)
  end

  def font_url(name)
    "https://fonts.example.test/#{CGI.escape(name)}.css"
  end

  def font_tags(content, *names, inline_styles: [])
    fonts = names.to_h { |name| [name, font_url(name)] }
    @renderer.send(:build_font_tags, content, inline_styles, fonts)
  end
end
