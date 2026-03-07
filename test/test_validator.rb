require "minitest/autorun"

require_relative "../lib/mjml-rb"

class ValidatorTest < Minitest::Test
  def validate(mjml)
    MjmlRb::Validator.new.validate(mjml)
  end

  def test_accepts_column_border_radius_port_case
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column border-radius="50px" inner-border-radius="40px" padding="50px" border="5px solid #000" inner-border="5px solid #666">
              <mj-text>Hello World</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(errors)
  end

  def test_accepts_image_with_required_src
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-image src="https://example.com/logo.png" alt="Logo" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(errors)
  end

  def test_rejects_image_without_src
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-image alt="Logo" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_includes(errors.map { |error| error[:message] }, "Attribute `src` is required for <mj-image>")
  end
end
