require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "stringio"
require_relative "../lib/mjml-rb"

class V5SupportTest < Minitest::Test
  def document(content, head: "", body: "", section: "")
    %(<mjml lang="ar" dir="rtl"><mj-head>#{head}</mj-head><mj-body #{body}><mj-section #{section}><mj-column>#{content}</mj-column></mj-section></mj-body></mjml>)
  end

  def compile(source, **options)
    MjmlRb::Compiler.new(options).compile(source)
  end

  def test_includes_are_ignored_by_default_even_in_strict_mode
    result = compile(document('<mj-include path="missing.mjml"/>'), validationLevel: "strict")
    assert_empty result.errors
    assert_empty result.warnings
    refute_includes result.html, "mj-include"
  end

  def test_allowlisted_includes_and_nested_context
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "templates"))
      FileUtils.mkdir_p(File.join(dir, "shared/nested"))
      File.write(File.join(dir, "shared/partial.mjml"), '<mj-include path="nested/inner.mjml"/>')
      File.write(File.join(dir, "shared/nested/inner.mjml"), '<mj-text>included</mj-text>')
      options = {ignoreIncludes: false, filePath: File.join(dir, "templates"), includePath: "../shared", validationLevel: "strict"}
      result = compile(document('<mj-include path="../shared/partial.mjml"/>'), **options)
      assert_empty result.errors
      assert_includes result.html, "included"
      assert_equal 2, result.dependencies.size
      assert_equal result.html, compile(document('<mj-include path="../shared/partial.mjml"/>'), **options.merge(includePath: ["../shared"])).html
    end
  end

  def test_include_escape_denials_for_all_types_and_validation_modes
    Dir.mktmpdir do |dir|
      root = File.join(dir, "templates")
      FileUtils.mkdir_p(root)
      secret = File.join(dir, "secret")
      File.write(secret, "SECRET_BYTES")
      File.symlink(secret, File.join(root, "link"))
      paths = ["../secret", "%2e%2e/secret", "%252e%252e%252fsecret", secret, "//server/secret", "C:/secret", "safe%00/secret", "link"]
      paths.product([nil, "html", "css"], %w[soft strict skip]).each do |path, type, level|
        source = document(%(<mj-include path="#{path}"#{type ? %( type="#{type}") : ''}/>))
        result = compile(source, file_path: root, ignore_includes: false, validation_level: level)
        diagnostic = (result.errors + result.warnings).first
        assert_equal "include-denied", diagnostic&.fetch(:type), [path, type, level].inspect
        assert_equal "mj-include", diagnostic[:tag_name]
        assert diagnostic[:line]
        refute_includes result.html, "SECRET_BYTES"
        assert_includes result.html, "<!-- mj-include denied -->" unless level == "strict"
      end
    end
  end

  def test_css_include_source_order_and_direct_validator_diagnostics
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "red.css"), '.target { color: red !important; }')
      File.write(File.join(dir, "blue.css"), '.target { color: blue !important; }')
      source = document('<mj-text><span class="target">Text</span></mj-text>', head: '<mj-include path="red.css" type="css" css-inline="inline"/><mj-style inline="inline">.target { color: green !important; }</mj-style><mj-include path="blue.css" type="css" css-inline="inline"/>')
      result = compile(source, ignore_includes: false, file_path: dir)
      assert_empty result.errors
      assert_includes Nokogiri::HTML(result.html).at_css('.target')["style"], "color: blue"
      invalid = MjmlRb::Validator.new.validate(document('<mj-include path="missing.mjml"/>'), ignore_includes: false, file_path: dir, validation_level: "strict")
      refute_empty invalid[:errors]
      assert_equal "mj-include", invalid[:errors].first[:tag_name]
    end
  end

  def test_nested_include_locations_and_failed_parse_dependencies
    Dir.mktmpdir do |dir|
      dir = File.realpath(dir)
      partial, leaf = %w[partial.mjml leaf.mjml].map { |name| File.join(dir, name) }
      File.write(partial, "<mjml>\n<mj-head>\n<mj-title typo=\"bad\">Title</mj-title>\n</mj-head>\n<mj-body><mj-include path=\"leaf.mjml\"/></mj-body>\n</mjml>")
      File.write(leaf, "<mj-text>First</mj-text>\n<mj-text typo=\"bad\">Second</mj-text>")
      source = document('<mj-include path="partial.mjml"/>')
      options = {ignore_includes: false, file_path: dir, validation_level: "strict"}
      result = compile(source, **options)
      assert_equal [[leaf, 2], [partial, 3]].sort, result.errors.map { |error| error.values_at(:file, :line) }.sort

      File.write(leaf, '<mj-section>')
      result = compile(source, **options)
      assert_equal [partial, leaf], result.dependencies
      assert_equal leaf, result.errors.first[:file]
      assert result.errors.first[:line].positive?

      File.write(leaf, '<mj-include path="partial.mjml"/>')
      result = compile(source, **options)
      assert_equal [partial, leaf], result.dependencies.uniq
      assert_match(/Circular inclusion/, result.errors.first[:message])
    end
  end

  def test_shared_compiler_keeps_concurrent_results_isolated
    compiler = MjmlRb::Compiler.new(preprocessors: [->(source) { Thread.pass; source }])
    sources = 4.times.map { |index| document("<mj-text>Message #{index}</mj-text>", head: "<mj-title>Title #{index}</mj-title>") }
    expected = sources.map { |source| compiler.compile(source).html }
    results = sources.map do |source|
      Thread.new { 10.times.map { compiler.compile(source).html } }
    end.map(&:value)
    results.each_with_index { |outputs, index| assert_equal [expected[index]] * 10, outputs }
  end

  def test_raw_siblings_and_social_content_and_borders
    %w[horizontal vertical].each do |mode|
      social = %(<mj-social mode="#{mode}" border="1px solid red"><mj-raw><!-- social raw --></mj-raw><mj-social-element name="github"><b>A & B</b></mj-social-element><mj-social-element name="facebook" border="2px dashed blue"/></mj-social>)
      source = document(social).sub('<mj-column>', '<mj-raw><!-- section raw --></mj-raw><mj-column>')
      result = compile(source, validation_level: "strict")
      assert_empty result.errors
      assert_includes result.html, "<!-- section raw -->"
      assert_includes result.html, "<!-- social raw -->"
      assert_includes result.html, "<b>A & B</b>"
      icons = Nokogiri::HTML(result.html).css('img')
      assert_includes icons[0]["style"], "border:1px solid red"
      assert_includes icons[1]["style"], "border:2px dashed blue"
    end
    result = compile('<mjml><mj-body><mj-wrapper><mj-raw><!-- wrapper raw --></mj-raw><mj-section><mj-column/></mj-section></mj-wrapper></mj-body></mjml>')
    assert_includes result.html, "<!-- wrapper raw -->"
  end

  def test_formatter_preserves_raw_text_and_outlook_for_all_combinations
    raw = "<!--[if mso | IE]><pre> a   b\n  c </pre><![endif]--><script>if (a && b) { x = '  '; }</script><span>A</span>  <span>B</span>"
    source = document("<!-- source comment --><mj-raw>#{raw}</mj-raw><mj-text>End</mj-text>")
    [true, false].repeated_permutation(3).each do |keep, minify, beautify|
      result = compile(source, keep_comments: keep, minify: minify, beautify: beautify)
      assert_empty result.errors
      assert_includes result.html, raw
      assert_includes result.html, "OfficeDocumentSettings"
      assert_includes result.html, "<!--[if mso | IE]>"
      assert_equal keep, result.html.include?("<!-- source comment -->")
    end
  end

  def test_ignore_regions_and_minify_precedence
    raw = "<div>  first\n  second </div>"
    source = document("<mj-raw><!-- htmlmin:ignore -->#{raw}<!-- htmlmin:ignore --><!-- htmlmin:ignore -->  third  <!-- htmlmin:ignore --></mj-raw>")
    minified = compile(source, minify: true).html
    assert_includes minified, raw
    assert_includes minified, "  third  "
    refute_includes minified, "htmlmin:ignore"
    assert_equal minified, compile(source, minify: true, beautify: true).html
  end

  def test_template_variables_and_errors
    head = '<mj-style>.a { color: {{ color }}; [[ property ]]: [[ value ]]; }</mj-style>'
    result = compile(document('<mj-text>Text</mj-text>', head: head), minify: true, sanitizeStyles: true)
    assert_empty result.errors
    ['{{ color }}', '[[ property ]]', '[[ value ]]'].each { |token| assert_includes result.html, token }
    broken = compile(document('<mj-text>Text</mj-text>', head: '<mj-style>.a { color: {{ broken; }</mj-style>'), sanitize_styles: true)
    assert_match(/Unbalanced template/, broken.errors.first[:message])
    mixed = document('<mj-raw><div style="[[ block ]]; color: {{ value }};">Text</div></mj-raw>')
    refute_empty compile(mixed, sanitize_styles: true, minify: true).errors
    assert_empty compile(mixed, sanitize_styles: true, allow_mixed_syntax: true, minify: true).errors
    inline = document('<mj-text>Text</mj-text>', head: '<mj-style inline="inline">.a { color: {{ color }}; }</mj-style>')
    assert_match(/inline MJML CSS is unsupported/, compile(inline, sanitize_styles: true).errors.first[:message])
  end

  def test_css_compaction_preserves_selector_meaning_and_literal_placeholder_names
    source = document('<mj-text>Text</mj-text>', head: '<mj-style>.a :hover { content: "mjmlrbvariable0token  text"; color: {{ color }}; }</mj-style>')
    result = compile(source, minify: true, sanitize_styles: true)
    assert_empty result.errors
    assert_includes result.html, '.a :hover{content:"mjmlrbvariable0token  text";color:{{ color }};}'
  end

  def test_option_aliases_conflicts_and_unsupported_options
    source = document('<mj-text>Text</mj-text>')
    assert_equal compile(source, keep_comments: false, validation_level: "strict").html, compile(source, keepComments: false, validationLevel: "strict").html
    assert_raises(ArgumentError) { compile(source, keep_comments: false, keepComments: true) }
    assert_raises(ArgumentError) { compile(source, juiceOptions: {preserveImportant: true}) }
    assert_raises(ArgumentError) { compile(source, minifyOptions: {removeEmptyElements: true}) }
    assert_equal compile(source, minify: true, minify_options: {minify_css: false}).html, compile(source, minify: true, minifyOptions: {minifyCSS: false}).html
  end

  def test_registry_sees_late_registration_and_rejects_collisions
    compiler = MjmlRb::Compiler.new(validation_level: "strict")
    compiler.compile(document('<mj-text>Warm</mj-text>'))
    klass = Class.new(MjmlRb::Components::Base) do
      const_set(:TAGS, ['mj-v5-custom'])
      def render(tag_name:, node:, context:, attrs:, parent:)
        "<div>#{raw_inner(node)}</div>"
      end
    end
    MjmlRb.register_component(klass, ending_tags: ['mj-v5-custom'], dependencies: {'mj-column' => ['mj-v5-custom']})
    result = compiler.compile(document('<mj-v5-custom>A < B && C</mj-v5-custom>'))
    assert_empty result.errors
    assert_includes result.html, "A < B && C"
    collision = Class.new(klass) { const_set(:TAGS, ['mj-text']) }
    assert_raises(ArgumentError) { MjmlRb.register_component(collision) }
  ensure
    MjmlRb.component_registry.reset!
  end

  def test_empty_images_fonts_and_unknown_attributes
    assert_empty compile(document('<mj-image/>', head: '<mj-font/>'), validation_level: 'strict').errors
    refute_empty compile(document('<mj-text>Text</mj-text>', head: '<mj-title typo="x">Title</mj-title>'), validation_level: 'strict').errors
  end
end
