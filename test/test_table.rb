require "minitest/autorun"

require_relative "../lib/mjml-rb"

class TableTest < Minitest::Test
  FIXTURES_DIR = File.join(__dir__, "fixtures/table")

  def compile(mjml, validation_level: "strict")
    MjmlRb::Compiler.new(validation_level: validation_level).compile(mjml)
  end

  def expected(name)
    File.read(File.join(FIXTURES_DIR, "#{name}.html"))
  end

  def test_table_preserves_cellspacing_and_uses_separate_border_collapse
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-table border="1px solid #000" width="auto" cellpadding="20" cellspacing="10" css-class="my-table">
                <tr style="border-bottom:1px solid #000;text-align:left;">
                  <th style="background:#ddd;">Year</th>
                  <th style="background:#ddd;">Language</th>
                  <th style="background:#ddd;">Inspired from</th>
                </tr>
                <tr>
                  <td style="background:#ddd;">1995</td>
                  <td style="background:#ddd;">PHP</td>
                  <td style="background:#ddd;">C, Shell Unix</td>
                </tr>
              </mj-table>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_includes result.html, expected("cellspacing")
  end

  def test_table_width_matches_upstream_cases
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-wrapper>
            <mj-section>
              <mj-column>
                <mj-table css-class="table">
                  <tr><th>Default Width</th><td>100%</td></tr>
                </mj-table>
              </mj-column>
            </mj-section>
            <mj-section>
              <mj-column>
                <mj-table width="500px" css-class="table">
                  <tr><th>Pixel Width</th><td>500px</td></tr>
                </mj-table>
              </mj-column>
            </mj-section>
            <mj-section>
              <mj-column>
                <mj-table width="80%" css-class="table">
                  <tr><th>Percentage Width</th><td>80%</td></tr>
                </mj-table>
              </mj-column>
            </mj-section>
            <mj-section>
              <mj-column>
                <mj-table width="auto" css-class="table">
                  <tr><th>Auto Width</th><td>Auto</td></tr>
                </mj-table>
              </mj-column>
            </mj-section>
          </mj-wrapper>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_includes result.html, expected("width")
  end

  def test_table_supports_font_weight_in_strict_mode
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-table css-class="report-table" font-weight="700" table-layout="fixed">
                <tr>
                  <td>Cell</td>
                </tr>
              </mj-table>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_includes result.html, expected("font_weight")
  end

  def test_mj_table_allows_tr_children_in_strict_mode
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-table>
                <tr><td>A</td></tr>
                <tr><td>B</td></tr>
              </mj-table>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_includes result.html, expected("tr_children")
  end

  def test_mj_table_normalizes_raw_html_table_children
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-table padding="0" css-class="padding--none--this">
                <tr>
                  <td style="direction: ltr">
                    <table>
                      <tr>
                        <td style="width: 60px; padding-right: 10px;">A</td>
                        <td style="vertical-align: middle; font-size: 15px;">B</td>
                      </tr>
                    </table>
                  </td>
                  <td style="text-align: right">C</td>
                </tr>
              </mj-table>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_includes result.html, expected("nested_html")
  end

  def test_mj_table_normalization_preserves_nested_links_with_inherited_font_family
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-table css-class="link-table">
                <tr>
                  <td>
                    <a href="https://example.com" style="color: #cc0000;">Link</a>
                  </td>
                </tr>
              </mj-table>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_includes result.html, expected("nested_links")
  end

  def test_mj_table_preserves_significant_spaces_between_inline_html_elements
    result = compile(<<~MJML)
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-table>
                <tr>
                  <td>
                    <p>As a <img src="x.png" width="30" style="width: 30px;" /> <strong>PLATINUM</strong> member</p>
                  </td>
                </tr>
              </mj-table>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_empty(result.errors)
    assert_includes result.html, expected("inline_spaces")
  end
end
