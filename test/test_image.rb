require "minitest/autorun"

require_relative "../lib/mjml-rb"

class ImageTest < Minitest::Test
  FIXTURES_DIR = File.join(__dir__, "fixtures/image")

  def compile(mjml, **opts)
    MjmlRb::Compiler.new(**opts).compile(mjml)
  end

  def expected(name)
    File.read(File.join(FIXTURES_DIR, "#{name}.html"))
  end

  def test_image_renders_with_src
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-image src="https://example.com/image.jpg" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, expected("renders_with_src")
  end

  def test_image_default_alt_is_empty
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-image src="https://example.com/image.jpg" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, expected("default_alt_is_empty")
  end

  def test_image_custom_alt
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-image src="test.jpg" alt="My Image" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, expected("custom_alt")
  end

  def test_image_with_href_wraps_in_link
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-image src="test.jpg" href="https://example.com" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, expected("with_href_wraps_in_link")
  end

  def test_image_without_href_no_link
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-image src="test.jpg" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, expected("without_href_no_link")
  end

  def test_image_custom_width
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-image src="test.jpg" width="200px" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, expected("custom_width")
  end

  def test_image_custom_height
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-image src="test.jpg" height="150px" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, expected("custom_height")
  end

  def test_image_height_auto
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-image src="test.jpg" height="auto" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, expected("height_auto")
  end

  def test_image_fluid_on_mobile
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-image src="test.jpg" fluid-on-mobile="true" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, expected("fluid_on_mobile")
  end

  def test_image_border_radius
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-image src="test.jpg" border-radius="10px" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, expected("border_radius")
  end

  def test_image_container_background_color
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-image src="test.jpg" container-background-color="#eeeeee" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, expected("container_background_color")
  end

  def test_image_custom_target
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-image src="test.jpg" href="https://example.com" target="_self" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, expected("custom_target")
  end

  def test_image_srcset_and_sizes
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-image src="test.jpg" srcset="test-2x.jpg 2x" sizes="(max-width: 600px) 100vw" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, expected("srcset_and_sizes")
  end

  def test_image_passes_strict_validation
    result = compile(<<~MJML, validation_level: "strict")
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-image
                src="https://example.com/img.png"
                alt="Test"
                href="https://example.com"
                width="300px"
                height="200px"
                padding="10px 20px"
                border-radius="5px"
                align="center"
                container-background-color="#ffffff"
                fluid-on-mobile="true"
                target="_blank"
              />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
  end

  def test_image_head_style_responsive
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-image src="test.jpg" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, expected("head_style_responsive")
  end
end
