require "minitest/autorun"
require "nokogiri"

require_relative "../lib/mjml-rb"

class SocialTest < Minitest::Test
  EXPECTED_SOCIAL_NETWORKS = {
    "facebook" => {
      "share-url" => "https://www.facebook.com/sharer/sharer.php?u=[[URL]]",
      "background-color" => "#3b5998",
      "src" => "https://www.mailjet.com/images/theme/v1/icons/ico-social/facebook.png"
    },
    "twitter" => {
      "share-url" => "https://twitter.com/intent/tweet?url=[[URL]]",
      "background-color" => "#55acee",
      "src" => "https://www.mailjet.com/images/theme/v1/icons/ico-social/twitter.png"
    },
    "x" => {
      "share-url" => "https://twitter.com/intent/tweet?url=[[URL]]",
      "background-color" => "#000000",
      "src" => "https://www.mailjet.com/images/theme/v1/icons/ico-social/twitter-x.png"
    },
    "google" => {
      "share-url" => "https://plus.google.com/share?url=[[URL]]",
      "background-color" => "#dc4e41",
      "src" => "https://www.mailjet.com/images/theme/v1/icons/ico-social/google-plus.png"
    },
    "pinterest" => {
      "share-url" => "https://pinterest.com/pin/create/button/?url=[[URL]]&media=&description=",
      "background-color" => "#bd081c",
      "src" => "https://www.mailjet.com/images/theme/v1/icons/ico-social/pinterest.png"
    },
    "linkedin" => {
      "share-url" => "https://www.linkedin.com/shareArticle?mini=true&url=[[URL]]&title=&summary=&source=",
      "background-color" => "#0077b5",
      "src" => "https://www.mailjet.com/images/theme/v1/icons/ico-social/linkedin.png"
    },
    "instagram" => {
      "background-color" => "#3f729b",
      "src" => "https://www.mailjet.com/images/theme/v1/icons/ico-social/instagram.png"
    },
    "web" => {
      "background-color" => "#4BADE9",
      "src" => "https://www.mailjet.com/images/theme/v1/icons/ico-social/web.png"
    },
    "snapchat" => {
      "background-color" => "#FFFA54",
      "src" => "https://www.mailjet.com/images/theme/v1/icons/ico-social/snapchat.png"
    },
    "youtube" => {
      "background-color" => "#EB3323",
      "src" => "https://www.mailjet.com/images/theme/v1/icons/ico-social/youtube.png"
    },
    "tumblr" => {
      "share-url" => "https://www.tumblr.com/widgets/share/tool?canonicalUrl=[[URL]]",
      "background-color" => "#344356",
      "src" => "https://www.mailjet.com/images/theme/v1/icons/ico-social/tumblr.png"
    },
    "github" => {
      "background-color" => "#000000",
      "src" => "https://www.mailjet.com/images/theme/v1/icons/ico-social/github.png"
    },
    "xing" => {
      "share-url" => "https://www.xing.com/app/user?op=share&url=[[URL]]",
      "background-color" => "#296366",
      "src" => "https://www.mailjet.com/images/theme/v1/icons/ico-social/xing.png"
    },
    "vimeo" => {
      "background-color" => "#53B4E7",
      "src" => "https://www.mailjet.com/images/theme/v1/icons/ico-social/vimeo.png"
    },
    "medium" => {
      "background-color" => "#000000",
      "src" => "https://www.mailjet.com/images/theme/v1/icons/ico-social/medium.png"
    },
    "soundcloud" => {
      "background-color" => "#EF7F31",
      "src" => "https://www.mailjet.com/images/theme/v1/icons/ico-social/soundcloud.png"
    },
    "dribbble" => {
      "background-color" => "#D95988",
      "src" => "https://www.mailjet.com/images/theme/v1/icons/ico-social/dribbble.png"
    }
  }.freeze

  def compile(mjml, validation_level: "strict")
    MjmlRb::Compiler.new(validation_level: validation_level).compile(mjml)
  end

  def validate(mjml)
    result = MjmlRb::Validator.new.validate(mjml, validation_level: "strict")
    result[:errors]
  end

  def test_social_accepts_table_layout_attribute
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-social table-layout="fixed" mode="horizontal">
                <mj-social-element name="facebook" href="https://facebook.com">Facebook</mj-social-element>
              </mj-social>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty result.errors
    assert_includes result.html, "Facebook"
  end

  def test_social_rejects_invalid_table_layout_value
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-social table-layout="invalid">
                <mj-social-element name="facebook" href="https://facebook.com">Facebook</mj-social-element>
              </mj-social>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    table_layout_errors = errors.select { |e| e[:message].include?("table-layout") }
    refute_empty table_layout_errors
  end

  def test_social_rejects_unknown_attribute
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-social bogus="yes">
                <mj-social-element name="facebook" href="https://facebook.com">Facebook</mj-social-element>
              </mj-social>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    bogus_errors = errors.select { |e| e[:message].include?("bogus") }
    refute_empty bogus_errors
  end

  def test_social_element_validates_attributes
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-social>
                <mj-social-element name="facebook" href="https://facebook.com" align="center">Facebook</mj-social-element>
              </mj-social>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty errors
  end

  def test_social_element_rejects_unknown_attribute
    errors = validate(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-social>
                <mj-social-element name="facebook" href="https://facebook.com" unknown-attr="yes">Facebook</mj-social-element>
              </mj-social>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    unknown_errors = errors.select { |e| e[:message].include?("unknown-attr") }
    refute_empty unknown_errors
  end

  def test_social_horizontal_rendering
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-social mode="horizontal" align="center">
                <mj-social-element name="facebook" href="https://facebook.com">Facebook</mj-social-element>
                <mj-social-element name="twitter" href="https://twitter.com">Twitter</mj-social-element>
              </mj-social>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty result.errors
    doc = Nokogiri::HTML(result.html)

    assert_includes result.html, "Facebook"
    assert_includes result.html, "Twitter"
    assert_includes result.html, "display:inline-table"
  end

  # Ported from upstream: social-align.test.js
  def test_social_element_align_renders_text_align_in_style
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-social mode="vertical">
                <mj-social-element name="facebook" href="https://mjml.io/" icon-position="right" align="right" css-class="my-social-element">
                  Facebook
                </mj-social-element>
              </mj-social>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty result.errors
    doc = Nokogiri::HTML(result.html)
    tr = doc.at_css("tr.my-social-element")
    refute_nil tr, "Expected a <tr> with class my-social-element"

    # The text <td> should have text-align:right
    text_td = tr.css("td").find { |td| td["style"]&.include?("text-align") }
    refute_nil text_td, "Expected a <td> with text-align style"
    assert_match(/text-align:\s*right/, text_td["style"])
  end

  # Ported from upstream: social-icon-height.test.js
  def test_social_icon_height_renders_in_td_style
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-social icon-height="40px">
                <mj-social-element name="facebook" href="https://mjml.io/" css-class="my-social-element">
                  Facebook
                </mj-social-element>
              </mj-social>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty result.errors
    doc = Nokogiri::HTML(result.html)
    tr = doc.at_css("tr.my-social-element")
    refute_nil tr, "Expected a <tr> with class my-social-element"

    # The icon <td> should have height:40px in its style
    icon_td = tr.css("td").find { |td| td["style"]&.match?(/height:\s*40px/) }
    refute_nil icon_td, "Expected a <td> with height:40px style"
  end

  def test_social_vertical_rendering
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-social mode="vertical">
                <mj-social-element name="github" href="https://github.com">GitHub</mj-social-element>
              </mj-social>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty result.errors
    assert_includes result.html, "GitHub"
  end

  # Verify html_attrs consolidation: alt="" preserved, nil attrs omitted
  def test_social_element_img_preserves_empty_alt_and_omits_nil_title
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-social>
                <mj-social-element name="facebook" href="https://facebook.com"></mj-social-element>
              </mj-social>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty result.errors
    doc = Nokogiri::HTML(result.html)
    img = doc.at_css("img[src*='facebook']")
    refute_nil img, "Expected an <img> for facebook icon"

    # alt="" must be present (empty string preserved, not dropped)
    assert_equal "", img["alt"], "alt attribute should be empty string, not missing"

    # title is nil by default — should be omitted entirely
    assert_nil img["title"], "title attribute should not be rendered when nil"
  end

  def test_social_element_img_renders_title_when_provided
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-social>
                <mj-social-element name="github" href="https://github.com" alt="GH" title="GitHub">GitHub</mj-social-element>
              </mj-social>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty result.errors
    doc = Nokogiri::HTML(result.html)
    img = doc.at_css("img[src*='github']")
    refute_nil img

    assert_equal "GH", img["alt"]
    assert_equal "GitHub", img["title"]
  end

  def test_social_network_defaults_match_upstream_icon_definitions
    actual = MjmlRb::Components::Social::SOCIAL_NETWORKS

    EXPECTED_SOCIAL_NETWORKS.each do |name, attrs|
      assert_equal attrs, actual[name]

      noshare_name = "#{name}-noshare"
      assert_equal attrs["src"], actual[noshare_name]["src"]
      assert_equal attrs["background-color"], actual[noshare_name]["background-color"]
      assert_equal "[[URL]]", actual[noshare_name]["share-url"]
    end
  end
end
