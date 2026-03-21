require "minitest/autorun"
require "nokogiri"

require_relative "../lib/mjml-rb"

class DividerTest < Minitest::Test
  def compile(mjml, **opts)
    MjmlRb::Compiler.new(**opts).compile(mjml)
  end

  def test_divider_renders_with_defaults
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-divider />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, "border-top:solid 4px #000000"
    assert_includes result.html, "margin:0px auto"
  end

  def test_divider_custom_border_attributes
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-divider
                border-color="#ff0000"
                border-style="dashed"
                border-width="2px"
              />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, "border-top:dashed 2px #ff0000"
  end

  def test_divider_custom_width
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-divider width="50%" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, "width:50%"
  end

  def test_divider_left_alignment
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-divider align="left" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, 'align="left"'
    assert_includes result.html, "margin:0px"
  end

  def test_divider_right_alignment
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-divider align="right" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, 'align="right"'
    assert_includes result.html, "margin:0px 0px 0px auto"
  end

  def test_divider_container_background_color
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-divider container-background-color="#eeeeee" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, "background:#eeeeee"
  end

  def test_divider_custom_padding
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-divider padding="20px 30px" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, "padding:20px 30px"
  end

  def test_divider_outlook_block
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-divider />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, "<!--[if mso | IE]>"
    assert_includes result.html, "height:0;line-height:0;"
  end

  def test_divider_css_class
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-divider css-class="my-divider" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, 'class="my-divider"'
  end

  def test_divider_passes_strict_validation
    result = compile(<<~MJML, validation_level: "strict")
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-divider
                border-color="#cccccc"
                border-style="dotted"
                border-width="1px"
                padding="5px 10px 15px 20px"
                width="80%"
                align="center"
                container-background-color="#fafafa"
              />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
  end
end
