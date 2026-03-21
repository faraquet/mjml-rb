require "minitest/autorun"
require "tmpdir"
require "stringio"

require_relative "../lib/mjml-rb"

class CLITest < Minitest::Test
  def setup
    @stdout = StringIO.new
    @stderr = StringIO.new
    @cli = MjmlRb::CLI.new(stdout: @stdout, stderr: @stderr)
  end

  def with_tempfile(content, ext = ".mjml")
    Dir.mktmpdir do |dir|
      path = File.join(dir, "test#{ext}")
      File.write(path, content)
      yield path, dir
    end
  end

  MINIMAL_MJML = <<~MJML
    <mjml>
      <mj-body>
        <mj-section>
          <mj-column>
            <mj-text>Hello</mj-text>
          </mj-column>
        </mj-section>
      </mj-body>
    </mjml>
  MJML

  # --- Version ---

  def test_version_flag
    assert_raises(SystemExit) do
      @cli.run(["--version"])
    end
    assert_includes @stdout.string, "mjml-ruby"
    assert_includes @stdout.string, MjmlRb::VERSION
  end

  def test_short_version_flag
    assert_raises(SystemExit) do
      @cli.run(["-V"])
    end
    assert_includes @stdout.string, MjmlRb::VERSION
  end

  # --- Help ---

  def test_help_flag
    assert_raises(SystemExit) do
      @cli.run(["--help"])
    end
    assert_includes @stdout.string, "Usage:"
  end

  # --- Read mode ---

  def test_read_file_to_stdout
    with_tempfile(MINIMAL_MJML) do |path, _dir|
      exit_code = @cli.run(["-r", path, "-s"])
      assert_equal 0, exit_code
      assert_includes @stdout.string, "<!doctype html>"
      assert_includes @stdout.string, "Hello"
    end
  end

  def test_read_positional_argument
    with_tempfile(MINIMAL_MJML) do |path, _dir|
      exit_code = @cli.run([path, "-s"])
      assert_equal 0, exit_code
      assert_includes @stdout.string, "<!doctype html>"
    end
  end

  def test_read_file_to_output_file
    with_tempfile(MINIMAL_MJML) do |path, dir|
      output_path = File.join(dir, "output.html")
      exit_code = @cli.run(["-r", path, "-o", output_path])
      assert_equal 0, exit_code
      assert File.exist?(output_path)
      content = File.read(output_path)
      assert_includes content, "<!doctype html>"
    end
  end

  def test_read_file_to_output_directory
    with_tempfile(MINIMAL_MJML) do |path, dir|
      output_dir = File.join(dir, "out")
      Dir.mkdir(output_dir)
      exit_code = @cli.run(["-r", path, "-o", output_dir])
      assert_equal 0, exit_code
      output_file = File.join(output_dir, "test.html")
      assert File.exist?(output_file)
    end
  end

  # --- Validate mode ---

  def test_validate_valid_file
    with_tempfile(MINIMAL_MJML) do |path, _dir|
      exit_code = @cli.run(["-v", path, "-s"])
      assert_equal 0, exit_code
    end
  end

  def test_validate_invalid_file
    invalid_mjml = <<~MJML
      <mjml>
        <mj-body>
          <mj-text>Invalid: text not in section/column</mj-text>
        </mj-body>
      </mjml>
    MJML
    with_tempfile(invalid_mjml) do |path, _dir|
      exit_code = @cli.run(["-v", path, "-s"])
      assert_equal 1, exit_code
    end
  end

  # --- Config flags ---

  def test_config_key_value
    with_tempfile(MINIMAL_MJML) do |path, _dir|
      exit_code = @cli.run(["-r", path, "-s", "-c", "minify=true"])
      assert_equal 0, exit_code
      # Minified output should be compact
      refute_match(/>\s{2,}</, @stdout.string)
    end
  end

  def test_inline_config
    with_tempfile(MINIMAL_MJML) do |path, _dir|
      exit_code = @cli.run(["-r", path, "-s", "--config.beautify=true"])
      assert_equal 0, exit_code
    end
  end

  # --- No stdout file comment ---

  def test_no_stdout_file_comment_flag
    with_tempfile(MINIMAL_MJML) do |path, _dir|
      exit_code = @cli.run(["-r", path, "-s", "--noStdoutFileComment"])
      assert_equal 0, exit_code
      refute_includes @stdout.string, "<!-- FILE:"
    end
  end

  def test_stdout_file_comment_present_by_default
    with_tempfile(MINIMAL_MJML) do |path, _dir|
      exit_code = @cli.run(["-r", path, "-s"])
      assert_equal 0, exit_code
      assert_includes @stdout.string, "<!-- FILE:"
    end
  end

  # --- Error handling ---

  def test_no_input_returns_error
    exit_code = @cli.run([])
    assert_equal 1, exit_code
    assert_includes @stderr.string, "No input argument"
  end

  def test_nonexistent_file_returns_error
    exit_code = @cli.run(["-r", "/nonexistent/path/file.mjml", "-s"])
    assert_equal 1, exit_code
  end

  def test_too_many_input_args
    with_tempfile(MINIMAL_MJML) do |path, _dir|
      exit_code = @cli.run(["-r", path, "-i"])
      assert_equal 1, exit_code
      assert_includes @stderr.string, "Too many input"
    end
  end

  # --- Parse typed values ---

  def test_parse_typed_value_boolean
    cli = MjmlRb::CLI.new
    assert_equal true, cli.send(:parse_typed_value, nil)
    assert_equal true, cli.send(:parse_typed_value, "true")
    assert_equal false, cli.send(:parse_typed_value, "false")
  end

  def test_parse_typed_value_numbers
    cli = MjmlRb::CLI.new
    assert_equal 42, cli.send(:parse_typed_value, "42")
    assert_equal(-5, cli.send(:parse_typed_value, "-5"))
    assert_in_delta 3.14, cli.send(:parse_typed_value, "3.14")
  end

  def test_parse_typed_value_json
    cli = MjmlRb::CLI.new
    assert_equal({ "key" => "val" }, cli.send(:parse_typed_value, '{"key":"val"}'))
  end

  def test_parse_typed_value_string_fallback
    cli = MjmlRb::CLI.new
    assert_equal "hello", cli.send(:parse_typed_value, "hello")
  end

  # --- Replace extension ---

  def test_replace_extension_mjml_to_html
    cli = MjmlRb::CLI.new
    assert_equal "test.html", cli.send(:replace_extension, "test.mjml")
  end

  def test_replace_extension_keeps_other_extensions
    cli = MjmlRb::CLI.new
    assert_equal "test.txt", cli.send(:replace_extension, "test.txt")
  end

  def test_replace_extension_adds_html_when_no_extension
    cli = MjmlRb::CLI.new
    assert_equal "test.html", cli.send(:replace_extension, "test")
  end
end
