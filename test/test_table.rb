require "minitest/autorun"
require "nokogiri"

require_relative "../lib/mjml-rb"

class TableTest < Minitest::Test
  def compile(mjml, validation_level: "strict")
    MjmlRb::Compiler.new(validation_level: validation_level).compile(mjml)
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

    document = Nokogiri::HTML(result.html)
    table = document.at_css("td.my-table > table")

    refute_nil(table)
    assert_equal("10", table["cellspacing"])
    assert_equal("separate", extract_style_value(table["style"], "border-collapse"))
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

    document = Nokogiri::HTML(result.html)
    tables = document.css("td.table > table")

    assert_equal(%w[100% 500 80% auto], tables.map { |table| table["width"] })
    assert_equal(%w[100% 500px 80% auto], tables.map { |table| extract_style_value(table["style"], "width") })
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

    document = Nokogiri::HTML(result.html)
    table = document.at_css("td.report-table > table")

    refute_nil(table)
    assert_includes(table["style"].to_s, "font-weight:700")
    assert_includes(table["style"].to_s, "table-layout:fixed")
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
    assert_includes(result.html, "<tr><td style=\"font-family: inherit\">A</td></tr>")
    assert_includes(result.html, "<tr><td style=\"font-family: inherit\">B</td></tr>")
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
    assert_includes(result.html, 'class="padding--none--this"')
    assert_includes(result.html, 'font-family:inherit')
    assert_includes(result.html, '<table width="100%"')
    assert_includes(result.html, 'style="font-family: inherit; width: 100%"')
    assert_includes(result.html, '<td style="width: 60px; padding-right: 10px; font-family: inherit" width="60">A</td>')
    assert_includes(result.html, '<td style="vertical-align: middle; font-size: 15px; font-family: inherit" valign="middle">B</td>')
    assert_includes(result.html, '<td style="text-align: right; font-family: inherit" align="right">C</td>')
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

    document = Nokogiri::HTML(result.html)
    link = document.at_css("td.link-table a")

    refute_nil(link)
    assert_equal("https://example.com", link["href"])
    assert_equal("color: #cc0000; font-family: inherit", link["style"])
  end

  private

  def extract_style_value(style, property)
    entry = style.to_s.split(";").map(&:strip).find { |item| item.start_with?("#{property}:") }
    entry&.split(":", 2)&.last&.strip
  end
end
