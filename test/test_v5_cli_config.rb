require "minitest/autorun"
require "tmpdir"
require "json"
require "stringio"
require "timeout"
require "rbconfig"
require_relative "../lib/mjml-rb"

class V5CliConfigTest < Minitest::Test
  SOURCE = '<mjml><mj-body><mj-section><mj-column><mj-text>Hello</mj-text></mj-column></mj-section></mj-body></mjml>'

  def test_config_is_opt_in_and_explicit_options_win
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, '.mjmlconfig'), JSON.generate(options: {minify: true, minifyOptions: {minifyCss: false}, keepComments: false}))
      plain = MjmlRb::Compiler.new(mjmlConfigPath: dir).compile(SOURCE)
      refute_includes plain.html, '</head><body'
      configured = MjmlRb::Compiler.new(mjmlConfigPath: dir, useMjmlConfigOptions: true).compile(SOURCE)
      assert_includes configured.html, '</head><body'
      assert_includes configured.html, 'font-family:Ubuntu, Helvetica, Arial, sans-serif'
      explicit = MjmlRb::Compiler.new(mjmlConfigPath: dir, useMjmlConfigOptions: true, minify: false).compile(SOURCE)
      refute_includes explicit.html, '</head><body'
      overridden = MjmlRb::Compiler.new(mjmlConfigPath: dir, useMjmlConfigOptions: true, minifyOptions: {minifyCss: true}).compile(SOURCE)
      assert_includes overridden.html, 'font-family:Ubuntu,Helvetica,Arial,sans-serif'
    end
  end

  def test_bad_config_formats_have_controlled_errors
    Dir.mktmpdir do |dir|
      [[], true, nil].each do |root|
        File.write(File.join(dir, '.mjmlconfig'), JSON.generate(root))
        assert_raises(MjmlRb::ConfigFile::ConfigError) { MjmlRb::ConfigFile.load(dir) }
      end
      File.delete(File.join(dir, '.mjmlconfig'))
      File.write(File.join(dir, '.mjmlconfig.js'), 'throw new Error("should not execute")')
      error = assert_raises(MjmlRb::ConfigFile::ConfigError) { MjmlRb::ConfigFile.load(dir) }
      assert_includes error.message, 'JavaScript'
    end
  end

  def test_cli_validate_never_renders_or_writes_output
    Dir.mktmpdir do |dir|
      input, output = File.join(dir, 'input.mjml'), File.join(dir, 'output.html')
      File.write(input, SOURCE)
      stdout, stderr = StringIO.new, StringIO.new
      cli = MjmlRb::CLI.new(stdout: stdout, stderr: stderr)
      klass = Class.new(MjmlRb::Components::Base) do
        const_set(:TAGS, ['mj-validation-only'])
        def render(**)
          raise 'validation must not render'
        end
      end
      MjmlRb.register_component(klass, dependencies: {'mj-column' => ['mj-validation-only']})
      File.write(input, SOURCE.sub('<mj-text>Hello</mj-text>', '<mj-validation-only/>'))
      assert_equal 0, cli.run(['--validate', input, '-o', output])
      refute File.exist?(output)
      assert_empty stdout.string
      assert_empty stderr.string
      File.write(input, SOURCE.sub('<mj-text>Hello</mj-text>', '<mj-text typo="bad"/>'))
      assert_equal 1, cli.run(['--validate', input])
      assert_empty stdout.string
    ensure
      MjmlRb.component_registry.reset!
    end
  end

  def test_cli_reports_unknown_and_conflicting_options
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'input.mjml')
      File.write(path, SOURCE)
      [['--config.missing=true'], ['--config.keepComments=true', '--config.keep_comments=false']].each do |flags|
        stderr = StringIO.new
        assert_equal 1, MjmlRb::CLI.new(stdout: StringIO.new, stderr: stderr).run([path, *flags])
        assert_match(/Unknown|Conflicting/, stderr.string)
      end
    end
  end

  def test_stdin_path_allows_explicit_includes
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'partial.mjml'), '<mj-text>From stdin include</mj-text>')
      original = $stdin
      $stdin = StringIO.new(SOURCE.sub('<mj-text>Hello</mj-text>', '<mj-include path="partial.mjml"/>'))
      stdout, stderr = StringIO.new, StringIO.new
      assert_equal 0, MjmlRb::CLI.new(stdout: stdout, stderr: stderr).run(['--stdin', '--filePath', dir, '--config.allowIncludes'])
      assert_includes stdout.string, 'From stdin include'
      assert_empty stderr.string
    ensure
      $stdin = original
    end
  end

  def test_watch_follows_recursive_include_graph_changes
    Dir.mktmpdir do |dir|
      root, partial, leaf, output = %w[root.mjml partial.mjml leaf.mjml output.html].map { |name| File.join(dir, name) }
      File.write(root, SOURCE.sub('<mj-text>Hello</mj-text>', '<mj-include path="partial.mjml"/>'))
      File.write(partial, '<mj-text>First</mj-text>')
      pid = Process.spawn({'MJML_RB_NO_WARN' => '1'}, RbConfig.ruby, File.expand_path('../bin/mjml', __dir__), '-w', root, '-o', output, '--config.allowIncludes', out: File::NULL, err: File::NULL)
      wait_for(output, 'First')
      File.write(leaf, '<mj-text>Second</mj-text>')
      File.write(partial, '<mj-include path="leaf.mjml"/>')
      wait_for(output, 'Second')
      File.write(leaf, '<mj-text>Third</mj-text>')
      wait_for(output, 'Third')
      File.delete(leaf)
      wait_until { File.file?(output) && !File.read(output).include?('Third') }
      File.write(leaf, '<mj-text>Recreated</mj-text>')
      wait_for(output, 'Recreated')
    ensure
      Process.kill('TERM', pid) if pid
      Process.wait(pid) if pid
    end
  end

  private

  def wait_until(&block)
    Timeout.timeout(8) { sleep 0.05 until block.call }
  end

  def wait_for(path, content)
    wait_until { File.file?(path) && File.read(path).include?(content) }
    assert_includes File.read(path), content
  end
end
