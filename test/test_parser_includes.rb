require "minitest/autorun"
require "tmpdir"

require_relative "../lib/mjml-rb"

class ParserIncludesTest < Minitest::Test
  def setup
    @parser = MjmlRb::Parser.new
  end

  # --- Basic include expansion ---

  def test_include_expands_mjml_partial
    Dir.mktmpdir do |dir|
      partial = File.join(dir, "partial.mjml")
      main = File.join(dir, "main.mjml")
      File.write(partial, "<mj-text>Included text</mj-text>")
      File.write(main, <<~MJML)
        <mjml>
          <mj-body>
            <mj-section>
              <mj-column>
                <mj-include path="./partial.mjml" />
              </mj-column>
            </mj-section>
          </mj-body>
        </mjml>
      MJML

      ast = @parser.parse(File.read(main), actual_path: main, file_path: dir)
      body = find_child(ast, "mj-body")
      section = find_child(body, "mj-section")
      column = find_child(section, "mj-column")
      text = find_child(column, "mj-text")
      refute_nil text
      assert_includes text.content, "Included text"
    end
  end

  # --- Missing include path attribute ---

  def test_include_without_path_raises_error
    mjml = <<~MJML
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-include />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML

    assert_raises(MjmlRb::Parser::ParseError) do
      @parser.parse(mjml)
    end
  end

  # --- Missing include file ---

  def test_missing_include_file_collects_include_error
    Dir.mktmpdir do |dir|
      main = File.join(dir, "main.mjml")
      File.write(main, <<~MJML)
        <mjml>
          <mj-body>
            <mj-section>
              <mj-column>
                <mj-include path="./nonexistent.mjml" />
              </mj-column>
            </mj-section>
          </mj-body>
        </mjml>
      MJML

      @parser.parse(File.read(main), actual_path: main, file_path: dir)
      refute_empty @parser.include_errors
      assert @parser.include_errors.any? { |e| e[:message].include?("nonexistent.mjml") }
    end
  end

  # --- Circular include detection ---

  def test_circular_include_raises_error
    Dir.mktmpdir do |dir|
      file_a = File.join(dir, "a.mjml")
      file_b = File.join(dir, "b.mjml")
      main = File.join(dir, "main.mjml")
      File.write(file_a, '<mj-section><mj-column><mj-include path="./b.mjml" /></mj-column></mj-section>')
      File.write(file_b, '<mj-section><mj-column><mj-include path="./a.mjml" /></mj-column></mj-section>')
      File.write(main, <<~MJML)
        <mjml>
          <mj-body>
            <mj-include path="./a.mjml" />
          </mj-body>
        </mjml>
      MJML

      assert_raises(MjmlRb::Parser::ParseError) do
        @parser.parse(File.read(main), actual_path: main, file_path: dir)
      end
    end
  end

  # --- HTML type include ---

  def test_html_type_include_wraps_in_mj_raw
    Dir.mktmpdir do |dir|
      partial = File.join(dir, "snippet.html")
      main = File.join(dir, "main.mjml")
      File.write(partial, "<p>Raw HTML content</p>")
      File.write(main, <<~MJML)
        <mjml>
          <mj-body>
            <mj-section>
              <mj-column>
                <mj-include path="./snippet.html" type="html" />
              </mj-column>
            </mj-section>
          </mj-body>
        </mjml>
      MJML

      ast = @parser.parse(File.read(main), actual_path: main, file_path: dir)
      body = find_child(ast, "mj-body")
      section = find_child(body, "mj-section")
      column = find_child(section, "mj-column")
      raw = find_child(column, "mj-raw")
      refute_nil raw
      assert_includes raw.content, "Raw HTML content"
    end
  end

  # --- CSS type include ---

  def test_css_type_include_adds_mj_style_to_head
    Dir.mktmpdir do |dir|
      css_file = File.join(dir, "styles.css")
      main = File.join(dir, "main.mjml")
      File.write(css_file, ".custom { color: red; }")
      File.write(main, <<~MJML)
        <mjml>
          <mj-head></mj-head>
          <mj-body>
            <mj-section>
              <mj-column>
                <mj-include path="./styles.css" type="css" />
                <mj-text>Test</mj-text>
              </mj-column>
            </mj-section>
          </mj-body>
        </mjml>
      MJML

      ast = @parser.parse(File.read(main), actual_path: main, file_path: dir)
      head = find_child(ast, "mj-head")
      refute_nil head
      style = find_child(head, "mj-style")
      refute_nil style
    end
  end

  def test_css_inline_include_sets_inline_attribute
    Dir.mktmpdir do |dir|
      css_file = File.join(dir, "inline.css")
      main = File.join(dir, "main.mjml")
      File.write(css_file, "p { color: blue; }")
      File.write(main, <<~MJML)
        <mjml>
          <mj-head></mj-head>
          <mj-body>
            <mj-section>
              <mj-column>
                <mj-include path="./inline.css" type="css" css-inline="inline" />
                <mj-text>Test</mj-text>
              </mj-column>
            </mj-section>
          </mj-body>
        </mjml>
      MJML

      ast = @parser.parse(File.read(main), actual_path: main, file_path: dir)
      head = find_child(ast, "mj-head")
      style = find_child(head, "mj-style")
      refute_nil style
      assert_equal "inline", style.attributes["inline"]
    end
  end

  # --- CSS include creates head if missing ---

  def test_css_include_creates_mj_head_if_absent
    Dir.mktmpdir do |dir|
      css_file = File.join(dir, "style.css")
      main = File.join(dir, "main.mjml")
      File.write(css_file, ".x { font-size: 14px; }")
      File.write(main, <<~MJML)
        <mjml>
          <mj-body>
            <mj-section>
              <mj-column>
                <mj-include path="./style.css" type="css" />
                <mj-text>No head</mj-text>
              </mj-column>
            </mj-section>
          </mj-body>
        </mjml>
      MJML

      ast = @parser.parse(File.read(main), actual_path: main, file_path: dir)
      head = find_child(ast, "mj-head")
      refute_nil head, "mj-head should be created when CSS include is used without existing head"
    end
  end

  # --- Nested includes ---

  def test_nested_include_expansion
    Dir.mktmpdir do |dir|
      inner = File.join(dir, "inner.mjml")
      outer = File.join(dir, "outer.mjml")
      main = File.join(dir, "main.mjml")
      File.write(inner, "<mj-text>Deep nested</mj-text>")
      File.write(outer, '<mj-include path="./inner.mjml" />')
      File.write(main, <<~MJML)
        <mjml>
          <mj-body>
            <mj-section>
              <mj-column>
                <mj-include path="./outer.mjml" />
              </mj-column>
            </mj-section>
          </mj-body>
        </mjml>
      MJML

      ast = @parser.parse(File.read(main), actual_path: main, file_path: dir)
      body = find_child(ast, "mj-body")
      section = find_child(body, "mj-section")
      column = find_child(section, "mj-column")
      text = find_child(column, "mj-text")
      refute_nil text
      assert_includes text.content, "Deep nested"
    end
  end

  # --- Include with full mjml document ---

  def test_include_full_mjml_document_extracts_body_children
    Dir.mktmpdir do |dir|
      partial = File.join(dir, "full.mjml")
      main = File.join(dir, "main.mjml")
      File.write(partial, <<~MJML)
        <mjml>
          <mj-body>
            <mj-text>From full document</mj-text>
          </mj-body>
        </mjml>
      MJML
      File.write(main, <<~MJML)
        <mjml>
          <mj-body>
            <mj-section>
              <mj-column>
                <mj-include path="./full.mjml" />
              </mj-column>
            </mj-section>
          </mj-body>
        </mjml>
      MJML

      ast = @parser.parse(File.read(main), actual_path: main, file_path: dir)
      body = find_child(ast, "mj-body")
      section = find_child(body, "mj-section")
      column = find_child(section, "mj-column")
      text = find_child(column, "mj-text")
      refute_nil text
      assert_includes text.content, "From full document"
    end
  end

  # --- Include with head content ---

  def test_include_with_head_merges_head_children
    Dir.mktmpdir do |dir|
      partial = File.join(dir, "with_head.mjml")
      main = File.join(dir, "main.mjml")
      File.write(partial, <<~MJML)
        <mjml>
          <mj-head>
            <mj-title>Included Title</mj-title>
          </mj-head>
          <mj-body>
            <mj-text>Body from include</mj-text>
          </mj-body>
        </mjml>
      MJML
      File.write(main, <<~MJML)
        <mjml>
          <mj-head></mj-head>
          <mj-body>
            <mj-section>
              <mj-column>
                <mj-include path="./with_head.mjml" />
              </mj-column>
            </mj-section>
          </mj-body>
        </mjml>
      MJML

      ast = @parser.parse(File.read(main), actual_path: main, file_path: dir)
      head = find_child(ast, "mj-head")
      refute_nil head
      title = find_child(head, "mj-title")
      refute_nil title, "Expected mj-title from included file to be merged into head"
    end
  end

  # --- ignore_includes option ---

  def test_ignore_includes_skips_expansion
    Dir.mktmpdir do |dir|
      main = File.join(dir, "main.mjml")
      File.write(main, <<~MJML)
        <mjml>
          <mj-body>
            <mj-section>
              <mj-column>
                <mj-include path="./nonexistent.mjml" />
              </mj-column>
            </mj-section>
          </mj-body>
        </mjml>
      MJML

      # Should not raise even though file doesn't exist
      ast = @parser.parse(File.read(main), ignore_includes: true)
      body = find_child(ast, "mj-body")
      section = find_child(body, "mj-section")
      column = find_child(section, "mj-column")
      inc = find_child(column, "mj-include")
      refute_nil inc, "mj-include should remain in AST when ignore_includes is true"
    end
  end

  private

  def find_child(node, tag_name)
    return nil unless node
    node.element_children.find { |c| c.tag_name == tag_name }
  end
end
