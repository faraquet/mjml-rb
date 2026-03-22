require "minitest/autorun"
require "tmpdir"
require "json"
require "stringio"

require_relative "../lib/mjml-rb"

class ErrorReportingTest < Minitest::Test
  def setup
    MjmlRb.component_registry.reset!
  end

  def teardown
    MjmlRb.component_registry.reset!
  end

  # =========================================================================
  # ConfigFile: parse errors should raise, not silently return {}
  # =========================================================================

  def test_config_file_raises_on_invalid_json
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, ".mjmlrc"), "{ not valid json }")
      assert_raises(MjmlRb::ConfigFile::ConfigError) do
        MjmlRb::ConfigFile.load(dir)
      end
    end
  end

  def test_config_file_error_includes_file_path
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, ".mjmlrc"), "invalid")
      error = assert_raises(MjmlRb::ConfigFile::ConfigError) do
        MjmlRb::ConfigFile.load(dir)
      end
      assert_includes error.message, ".mjmlrc"
    end
  end

  def test_config_file_error_includes_parse_details
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, ".mjmlrc"), "{ broken: }")
      error = assert_raises(MjmlRb::ConfigFile::ConfigError) do
        MjmlRb::ConfigFile.load(dir)
      end
      assert_includes error.message, "Failed to parse"
    end
  end

  def test_config_file_valid_json_still_works
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, ".mjmlrc"), JSON.generate({ "options" => { "beautify" => true } }))
      result = MjmlRb::ConfigFile.load(dir)
      assert_equal true, result[:options][:beautify]
    end
  end

  def test_config_file_missing_file_still_returns_empty_hash
    Dir.mktmpdir do |dir|
      result = MjmlRb::ConfigFile.load(dir)
      assert_equal({}, result)
    end
  end

  # =========================================================================
  # Parser: missing include files should produce warnings, not HTML comments
  # =========================================================================

  def test_missing_include_produces_warning_in_soft_mode
    Dir.mktmpdir do |dir|
      main = File.join(dir, "main.mjml")
      File.write(main, <<~MJML)
        <mjml>
          <mj-body>
            <mj-section>
              <mj-column>
                <mj-include path="./nonexistent.mjml" />
                <mj-text>Still here</mj-text>
              </mj-column>
            </mj-section>
          </mj-body>
        </mjml>
      MJML

      compiler = MjmlRb::Compiler.new(actual_path: main, file_path: dir, validation_level: "soft")
      result = compiler.compile(File.read(main))

      # Should still render the rest of the template
      assert_includes result.html, "Still here"
      # Warning should be reported
      assert result.warnings.any? { |w| w[:message].include?("nonexistent.mjml") },
        "Expected a warning about the missing include file"
    end
  end

  def test_missing_include_produces_error_in_strict_mode
    Dir.mktmpdir do |dir|
      main = File.join(dir, "main.mjml")
      File.write(main, <<~MJML)
        <mjml>
          <mj-body>
            <mj-section>
              <mj-column>
                <mj-include path="./nonexistent.mjml" />
                <mj-text>Still here</mj-text>
              </mj-column>
            </mj-section>
          </mj-body>
        </mjml>
      MJML

      compiler = MjmlRb::Compiler.new(actual_path: main, file_path: dir, validation_level: "strict")
      result = compiler.compile(File.read(main))

      # In strict mode, include errors should be blocking
      refute result.success?
      assert result.errors.any? { |e| e[:message].include?("nonexistent.mjml") },
        "Expected an error about the missing include file"
    end
  end

  def test_missing_include_warning_contains_file_path
    Dir.mktmpdir do |dir|
      main = File.join(dir, "main.mjml")
      File.write(main, <<~MJML)
        <mjml>
          <mj-body>
            <mj-section>
              <mj-column>
                <mj-include path="./missing.mjml" />
              </mj-column>
            </mj-section>
          </mj-body>
        </mjml>
      MJML

      compiler = MjmlRb::Compiler.new(actual_path: main, file_path: dir)
      result = compiler.compile(File.read(main))

      warning = result.warnings.find { |w| w[:message].include?("missing.mjml") }
      refute_nil warning
      assert_includes warning[:message], "missing.mjml"
    end
  end

  def test_missing_css_include_produces_warning
    Dir.mktmpdir do |dir|
      main = File.join(dir, "main.mjml")
      File.write(main, <<~MJML)
        <mjml>
          <mj-body>
            <mj-section>
              <mj-column>
                <mj-include path="./nonexistent.css" type="css" />
                <mj-text>Still here</mj-text>
              </mj-column>
            </mj-section>
          </mj-body>
        </mjml>
      MJML

      compiler = MjmlRb::Compiler.new(actual_path: main, file_path: dir)
      result = compiler.compile(File.read(main))

      assert_includes result.html, "Still here"
      assert result.warnings.any? { |w| w[:message].include?("nonexistent.css") },
        "Expected a warning about the missing CSS include file"
    end
  end

  def test_missing_include_no_longer_leaks_html_comment_into_output
    Dir.mktmpdir do |dir|
      main = File.join(dir, "main.mjml")
      File.write(main, <<~MJML)
        <mjml>
          <mj-body>
            <mj-section>
              <mj-column>
                <mj-include path="./nonexistent.mjml" />
                <mj-text>Content</mj-text>
              </mj-column>
            </mj-section>
          </mj-body>
        </mjml>
      MJML

      compiler = MjmlRb::Compiler.new(actual_path: main, file_path: dir)
      result = compiler.compile(File.read(main))

      refute_includes result.html, "mj-include fails to read file",
        "HTML comment about missing include should no longer leak into output"
    end
  end

  def test_valid_include_still_works
    Dir.mktmpdir do |dir|
      partial = File.join(dir, "partial.mjml")
      main = File.join(dir, "main.mjml")
      File.write(partial, "<mj-text>From include</mj-text>")
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

      compiler = MjmlRb::Compiler.new(actual_path: main, file_path: dir)
      result = compiler.compile(File.read(main))

      assert_empty result.errors
      assert_empty result.warnings
      assert_includes result.html, "From include"
    end
  end

  # =========================================================================
  # CLI: config errors should be reported to stderr
  # =========================================================================

  def test_cli_reports_config_error_to_stderr
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, ".mjmlrc"), "{ broken json")
      input = File.join(dir, "test.mjml")
      File.write(input, "<mjml><mj-body></mj-body></mjml>")

      stdout = StringIO.new
      stderr = StringIO.new
      cli = MjmlRb::CLI.new(stdout: stdout, stderr: stderr)

      Dir.chdir(dir) do
        exit_code = cli.run([input, "-s"])
        assert_equal 1, exit_code
        assert_includes stderr.string, ".mjmlrc"
      end
    end
  end
end
