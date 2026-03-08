require "minitest/autorun"

require_relative "../lib/mjml-rb"

class GroupTest < Minitest::Test
  def compile(mjml, validation_level: "strict")
    MjmlRb::Compiler.new(validation_level: validation_level).compile(mjml)
  end

  def test_group_renders_columns_using_group_width_for_child_calculations
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-group width="50%" background-color="#eeeeee">
              <mj-column width="100px" padding="0">
                <mj-image src="https://example.com/one.jpg" padding="0" />
              </mj-column>
              <mj-column padding="0">
                <mj-image src="https://example.com/two.jpg" padding="0" />
              </mj-column>
            </mj-group>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)

    html = result.html
    assert_includes(html, 'background-color:#eeeeee')
    assert_includes(html, 'class="mj-column-per-50 mj-outlook-group-fix"')
    assert_includes(html, 'style="vertical-align:top;width:100px"')
    assert_includes(html, 'style="vertical-align:top;width:200px"')
    assert_includes(html, 'src="https://example.com/one.jpg"')
    assert_includes(html, 'src="https://example.com/two.jpg"')
    assert_includes(html, 'width="100"')
    assert_includes(html, 'width="200"')
  end

  def test_group_validates_supported_attributes_in_strict_mode
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-group invalid="1">
              <mj-column>
                <mj-text>Hello</mj-text>
              </mj-column>
            </mj-group>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_includes(result.errors.map { |error| error[:message] }, "Attribute `invalid` is not allowed for <mj-group>")
  end
end
