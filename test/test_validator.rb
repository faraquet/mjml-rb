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

  # ── unknown-attribute rejection tests ──────────────────────

  def test_rejects_unknown_attribute_on_mj_button
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-button href="#" fake-attr="x">Click</mj-button>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-button") })
  end

  def test_rejects_unknown_attribute_on_mj_image
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-image src="https://example.com/img.png" fake-attr="x" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-image") })
  end

  def test_rejects_unknown_attribute_on_mj_text
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text fake-attr="x">Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-text") })
  end

  def test_rejects_unknown_attribute_on_mj_divider
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-divider fake-attr="x" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-divider") })
  end

  def test_rejects_unknown_attribute_on_mj_spacer
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-spacer fake-attr="x" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-spacer") })
  end

  def test_rejects_unknown_attribute_on_mj_table
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-table fake-attr="x"><tr><td>A</td></tr></mj-table>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-table") })
  end

  def test_rejects_unknown_attribute_on_mj_raw
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-raw fake-attr="x">raw</mj-raw>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-raw") })
  end

  def test_rejects_unknown_attribute_on_mj_hero
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-hero fake-attr="x">
            <mj-text>Hello</mj-text>
          </mj-hero>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-hero") })
  end

  def test_rejects_unknown_attribute_on_mj_column
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column fake-attr="x">
              <mj-text>Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-column") })
  end

  def test_rejects_unknown_attribute_on_mj_section
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section fake-attr="x">
            <mj-column>
              <mj-text>Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-section") })
  end

  def test_rejects_unknown_attribute_on_mj_wrapper
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-wrapper fake-attr="x">
            <mj-section>
              <mj-column>
                <mj-text>Hello</mj-text>
              </mj-column>
            </mj-section>
          </mj-wrapper>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-wrapper") })
  end

  def test_rejects_unknown_attribute_on_mj_group
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-group fake-attr="x">
              <mj-column>
                <mj-text>Hello</mj-text>
              </mj-column>
            </mj-group>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-group") })
  end

  def test_rejects_unknown_attribute_on_mj_body
    errors = validate(<<~MJML)
      <mjml>
        <mj-body fake-attr="x">
          <mj-section>
            <mj-column>
              <mj-text>Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-body") })
  end

  def test_rejects_unknown_attribute_on_mj_carousel
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-carousel fake-attr="x">
                <mj-carousel-image src="https://example.com/1.jpg" />
              </mj-carousel>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-carousel") })
  end

  def test_rejects_unknown_attribute_on_mj_carousel_image
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-carousel>
                <mj-carousel-image src="https://example.com/1.jpg" fake-attr="x" />
              </mj-carousel>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-carousel-image") })
  end

  def test_rejects_unknown_attribute_on_mj_accordion
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-accordion fake-attr="x">
                <mj-accordion-element>
                  <mj-accordion-title>T</mj-accordion-title>
                  <mj-accordion-text>B</mj-accordion-text>
                </mj-accordion-element>
              </mj-accordion>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-accordion") })
  end

  def test_rejects_unknown_attribute_on_mj_navbar
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-navbar fake-attr="x">
                <mj-navbar-link href="/">Home</mj-navbar-link>
              </mj-navbar>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-navbar") })
  end

  def test_rejects_unknown_attribute_on_mj_navbar_link
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-navbar>
                <mj-navbar-link href="/" fake-attr="x">Home</mj-navbar-link>
              </mj-navbar>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-navbar-link") })
  end

  def test_rejects_unknown_attribute_on_mj_breakpoint
    errors = validate(<<~MJML)
      <mjml>
        <mj-head>
          <mj-breakpoint width="480px" fake-attr="x" />
        </mj-head>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text>Hello</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert(errors.any? { |e| e[:message].include?("fake-attr") && e[:message].include?("mj-breakpoint") })
  end
end
