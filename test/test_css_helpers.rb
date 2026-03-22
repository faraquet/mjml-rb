require "minitest/autorun"

require_relative "../lib/mjml-rb"

class CssHelpersTest < Minitest::Test
  include MjmlRb::Components::CssHelpers

  # =========================================================================
  # shorthand_value
  # =========================================================================

  def test_shorthand_value_single_value
    assert_equal "10px", shorthand_value(["10px"], :top)
    assert_equal "10px", shorthand_value(["10px"], :right)
    assert_equal "10px", shorthand_value(["10px"], :bottom)
    assert_equal "10px", shorthand_value(["10px"], :left)
  end

  def test_shorthand_value_two_values
    # top/bottom=5px, right/left=10px
    assert_equal "10px", shorthand_value(["5px", "10px"], :right)
    assert_equal "10px", shorthand_value(["5px", "10px"], :left)
  end

  def test_shorthand_value_three_values
    # top=5px, right/left=10px, bottom=15px
    assert_equal "10px", shorthand_value(["5px", "10px", "15px"], :right)
    assert_equal "10px", shorthand_value(["5px", "10px", "15px"], :left)
  end

  def test_shorthand_value_four_values
    # top=1, right=2, bottom=3, left=4
    parts = ["1px", "2px", "3px", "4px"]
    assert_equal "2px", shorthand_value(parts, :right)
    assert_equal "4px", shorthand_value(parts, :left)
  end

  def test_shorthand_value_empty_returns_zero
    assert_equal "0", shorthand_value([], :left)
  end

  # =========================================================================
  # parse_border_width
  # =========================================================================

  def test_parse_border_width_with_px
    assert_equal 2, parse_border_width("2px solid #000")
  end

  def test_parse_border_width_with_decimal
    assert_equal 1.5, parse_border_width("1.5px dashed red")
  end

  def test_parse_border_width_none
    assert_equal 0, parse_border_width("none")
  end

  def test_parse_border_width_nil
    assert_equal 0, parse_border_width(nil)
  end

  def test_parse_border_width_empty
    assert_equal 0, parse_border_width("")
    assert_equal 0, parse_border_width("  ")
  end

  def test_parse_border_width_no_px_unit
    assert_equal 0, parse_border_width("solid red")
  end

  def test_parse_border_width_plain_number_with_px
    assert_equal 5, parse_border_width("5px")
  end

  # =========================================================================
  # Verify components still produce same output after extraction
  # =========================================================================

  def test_button_renders_same_after_extraction
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-button href="https://example.com" padding="10px 20px 30px 40px">Click</mj-button>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, "Click"
    assert_includes result.html, 'href="https://example.com"'
  end

  def test_image_renders_same_after_extraction
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-image src="test.jpg" padding="10px 20px 30px 40px" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, 'src="test.jpg"'
  end

  def test_divider_renders_same_after_extraction
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-divider padding="10px 20px 30px 40px" border-color="#ff0000" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, "#ff0000"
  end

  def test_section_renders_same_after_extraction
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section border="2px solid #000" padding="10px 20px">
            <mj-column>
              <mj-text>Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, "Hello"
  end

  def test_button_with_border_uses_shared_parse_border_width
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-button href="#" border="3px solid blue">Bordered</mj-button>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
    assert_empty result.errors
    assert_includes result.html, "Bordered"
  end

  private

  def compile(mjml)
    MjmlRb::Compiler.new.compile(mjml)
  end
end
