require "minitest/autorun"
require "nokogiri"

require_relative "../lib/mjml-rb"

class CarouselTest < Minitest::Test
  def compile(mjml, validation_level: "strict")
    MjmlRb::Compiler.new(validation_level: validation_level).compile(mjml)
  end

  def test_carousel_renders_radios_controls_images_and_thumbnails
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-carousel border-radius="8px" padding="0 25px">
                <mj-carousel-image
                  src="https://example.com/one.jpg"
                  href="https://example.com/first"
                  alt="One"
                />
                <mj-carousel-image
                  src="https://example.com/two.jpg"
                  thumbnails-src="https://example.com/two-thumb.jpg"
                  alt="Two"
                />
              </mj-carousel>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)

    html = result.html
    assert_equal(2, html.scan(/class="mj-carousel-radio /).length)
    assert_match(/id="mj-carousel-[0-9a-f]{16}-radio-1"/, html)
    assert_match(/id="mj-carousel-[0-9a-f]{16}-radio-2"/, html)
    assert_match(/class="mj-carousel-thumbnail mj-carousel-[0-9a-f]{16}-thumbnail mj-carousel-[0-9a-f]{16}-thumbnail-2"/, html)
    assert_includes(html, 'src="https://example.com/two-thumb.jpg"')
    assert_includes(html, 'class="mj-carousel-image mj-carousel-image-1"')
    assert_includes(html, 'class="mj-carousel-image mj-carousel-image-2"')
    assert_includes(html, 'src="https://i.imgur.com/xTh3hln.png"')
    assert_includes(html, 'src="https://i.imgur.com/os7o9kz.png"')
    assert_includes(html, 'border-radius:8px;display:block;width:550px;max-width:100%;height:auto')
    assert_match(/\.mj-carousel-[0-9a-f]{16}-radio-1:checked .*?\.mj-carousel-content .*?\.mj-carousel-image-1/m, html)
    assert_match(/\.mj-carousel-[0-9a-f]{16}-thumbnail:hover/m, html)
  end

  def test_carousel_respects_hidden_thumbnails_and_child_target
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-carousel thumbnails="hidden">
                <mj-carousel-image
                  src="https://example.com/one.jpg"
                  href="https://example.com/first"
                  target="_self"
                />
              </mj-carousel>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)

    html = result.html
    refute_includes(html, 'class="mj-carousel-thumbnail')
    assert_includes(html, 'href="https://example.com/first"')
    assert_includes(html, 'target="_self"')
  end

  # Ported from upstream: carousel-hoverSupported.test.js
  def test_carousel_thumbnails_supported_renders_display_none
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-carousel thumbnails="supported">
                <mj-carousel-image src="https://placehold.co/450x300/333/ccc/png" />
                <mj-carousel-image src="https://placehold.co/450x300/ccc/000/png" />
                <mj-carousel-image src="https://placehold.co/450x300/f45e43/fff/png" />
              </mj-carousel>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty result.errors

    doc = Nokogiri::HTML(result.html)
    thumbnails = doc.css(".mj-carousel-thumbnail")
    assert_equal 3, thumbnails.length, "Expected 3 thumbnail elements"

    display_values = thumbnails.map do |el|
      el["style"]&.match(/display:\s*([^;]+)/)&.captures&.first
    end
    assert_equal ["none", "none", "none"], display_values
  end

  def test_carousel_validates_component_attributes_in_strict_mode
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-carousel invalid="1">
                <mj-carousel-image src="https://example.com/one.jpg" extra="2" />
              </mj-carousel>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    messages = result.errors.map { |error| error[:message] }

    assert_includes(messages, "Attribute `invalid` is not allowed for <mj-carousel>")
    assert_includes(messages, "Attribute `extra` is not allowed for <mj-carousel-image>")
  end
end
