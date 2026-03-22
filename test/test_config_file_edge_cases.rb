require "minitest/autorun"
require "tmpdir"
require "json"

require_relative "../lib/mjml-rb"

class ConfigFileEdgeCasesTest < Minitest::Test
  def setup
    MjmlRb.component_registry.reset!
  end

  def teardown
    MjmlRb.component_registry.reset!
  end

  # --- packages as non-array ---

  def test_load_ignores_packages_when_not_array
    Dir.mktmpdir do |dir|
      write_mjmlrc(dir, { "packages" => "not_an_array" })
      result = MjmlRb::ConfigFile.load(dir)
      refute result.key?(:packages_loaded)
    end
  end

  # --- options as non-hash ---

  def test_load_ignores_options_when_not_hash
    Dir.mktmpdir do |dir|
      write_mjmlrc(dir, { "options" => "not_a_hash" })
      result = MjmlRb::ConfigFile.load(dir)
      refute result.key?(:options)
    end
  end

  # --- Empty config ---

  def test_load_handles_empty_json_object
    Dir.mktmpdir do |dir|
      write_mjmlrc(dir, {})
      result = MjmlRb::ConfigFile.load(dir)
      assert_equal({}, result)
    end
  end

  # --- Options with various key styles ---

  def test_load_normalizes_camelCase_option_keys
    Dir.mktmpdir do |dir|
      write_mjmlrc(dir, { "options" => { "keepComments" => true } })
      result = MjmlRb::ConfigFile.load(dir)
      # Keys with no dashes are just symbolized as-is
      assert_equal true, result[:options][:keepComments]
    end
  end

  def test_load_normalizes_dashed_option_keys
    Dir.mktmpdir do |dir|
      write_mjmlrc(dir, { "options" => { "ignore-includes" => true, "file-path" => "/tmp" } })
      result = MjmlRb::ConfigFile.load(dir)
      assert_equal true, result[:options][:ignore_includes]
      assert_equal "/tmp", result[:options][:file_path]
    end
  end

  # --- Options with various value types ---

  def test_load_preserves_integer_option_values
    Dir.mktmpdir do |dir|
      write_mjmlrc(dir, { "options" => { "some-number" => 42 } })
      result = MjmlRb::ConfigFile.load(dir)
      assert_equal 42, result[:options][:some_number]
    end
  end

  def test_load_preserves_string_option_values
    Dir.mktmpdir do |dir|
      write_mjmlrc(dir, { "options" => { "validation-level" => "strict" } })
      result = MjmlRb::ConfigFile.load(dir)
      assert_equal "strict", result[:options][:validation_level]
    end
  end

  # --- File at default name ---

  def test_load_uses_default_name
    assert_equal ".mjmlrc", MjmlRb::ConfigFile::DEFAULT_NAME
  end

  # --- Packages that fail to load ---

  def test_load_raises_on_missing_package
    Dir.mktmpdir do |dir|
      write_mjmlrc(dir, { "packages" => ["./does_not_exist.rb"] })
      assert_raises(LoadError) do
        MjmlRb::ConfigFile.load(dir)
      end
    end
  end

  private

  def write_mjmlrc(dir, config)
    File.write(File.join(dir, ".mjmlrc"), JSON.generate(config))
  end
end
