require "minitest/autorun"

require_relative "../lib/mjml-rb"

class GroupTest < Minitest::Test
  FIXTURES_DIR = File.join(__dir__, "fixtures/group")

  def compile(mjml, validation_level: "strict")
    MjmlRb::Compiler.new(validation_level: validation_level).compile(mjml)
  end

  def expected(name)
    File.read(File.join(FIXTURES_DIR, "#{name}.html"))
  end

  def body_of(html)
    html[/<body[^>]*>(.*)<\/body>/m, 1].strip
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
    assert_equal expected("group_width_child_calculations"), body_of(result.html)
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

  def test_group_keeps_child_columns_side_by_side_on_mobile
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-group>
              <mj-column>
                <mj-text>Left</mj-text>
              </mj-column>
              <mj-column>
                <mj-text>Right</mj-text>
              </mj-column>
            </mj-group>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_equal expected("columns_side_by_side"), body_of(result.html)
  end
end
