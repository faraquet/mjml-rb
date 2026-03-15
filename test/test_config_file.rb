require "minitest/autorun"
require "tmpdir"
require "json"

require_relative "../lib/mjml-rb"

class ConfigFileTest < Minitest::Test
  def setup
    MjmlRb.component_registry.reset!
  end

  def teardown
    MjmlRb.component_registry.reset!
  end

  def test_load_returns_empty_hash_when_no_file
    Dir.mktmpdir do |dir|
      result = MjmlRb::ConfigFile.load(dir)
      assert_equal({}, result)
    end
  end

  def test_load_parses_options
    Dir.mktmpdir do |dir|
      write_mjmlrc(dir, {"options" => {"beautify" => true, "keep-comments" => false}})

      result = MjmlRb::ConfigFile.load(dir)
      assert_equal true, result[:options][:beautify]
      assert_equal false, result[:options][:keep_comments]
    end
  end

  def test_load_normalizes_option_keys_to_symbols
    Dir.mktmpdir do |dir|
      write_mjmlrc(dir, {"options" => {"validation-level" => "strict"}})

      result = MjmlRb::ConfigFile.load(dir)
      assert_equal "strict", result[:options][:validation_level]
    end
  end

  def test_load_requires_packages_and_registers_components
    Dir.mktmpdir do |dir|
      component_file = File.join(dir, "my_component.rb")
      File.write(component_file, <<~RUBY)
        class MjCustomFromConfig < MjmlRb::Components::Base
          TAGS = ["mj-custom-from-config"].freeze
          ALLOWED_ATTRIBUTES = {}.freeze
          DEFAULT_ATTRIBUTES = {}.freeze

          def render(tag_name:, node:, context:, attrs:, parent:)
            "<div>from config</div>"
          end
        end

        MjmlRb.register_component(MjCustomFromConfig, dependencies: {"mj-column" => ["mj-custom-from-config"]})
      RUBY

      write_mjmlrc(dir, {"packages" => ["./my_component.rb"]})

      result = MjmlRb::ConfigFile.load(dir)
      assert_equal ["./my_component.rb"], result[:packages_loaded]

      found = MjmlRb.component_registry.component_class_for_tag("mj-custom-from-config")
      refute_nil found
    end
  end

  def test_load_handles_invalid_json_gracefully
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, ".mjmlrc"), "{ not valid json }")

      result = MjmlRb::ConfigFile.load(dir)
      assert_equal({}, result)
    end
  end

  def test_load_ignores_unknown_keys
    Dir.mktmpdir do |dir|
      write_mjmlrc(dir, {"unknown_key" => "value", "options" => {"beautify" => true}})

      result = MjmlRb::ConfigFile.load(dir)
      assert_equal true, result[:options][:beautify]
      refute result.key?(:unknown_key)
    end
  end

  def test_load_handles_empty_packages_array
    Dir.mktmpdir do |dir|
      write_mjmlrc(dir, {"packages" => []})

      result = MjmlRb::ConfigFile.load(dir)
      assert_equal [], result[:packages_loaded]
    end
  end

  private

  def write_mjmlrc(dir, config)
    File.write(File.join(dir, ".mjmlrc"), JSON.generate(config))
  end
end
