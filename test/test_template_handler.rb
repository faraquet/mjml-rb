require "minitest/autorun"

# Minimal stubs to test TemplateHandler without loading Rails.
# Must be defined BEFORE requiring template_handler.rb which does `require "action_view"`.
module ActionView
  class Template
    def self.registered_template_handler(name)
      nil
    end

    def self.register_template_handler(name, handler)
      @handlers ||= {}
      @handlers[name] = handler
    end
  end
end

# Prevent `require "action_view"` from failing by registering the stub above
$LOADED_FEATURES << "action_view.rb"
$LOADED_FEATURES << "action_view/template.rb"

require_relative "../lib/mjml-rb"
require_relative "../lib/mjml-rb/template_handler"

class TemplateHandlerTest < Minitest::Test
  def setup
    @handler = MjmlRb::TemplateHandler.new
  end

  # --- xml_source? ---

  def test_xml_source_with_xml_content
    assert @handler.send(:xml_source?, "<mjml><mj-body></mj-body></mjml>")
  end

  def test_xml_source_with_leading_whitespace
    assert @handler.send(:xml_source?, "  <mjml>")
  end

  def test_xml_source_with_non_xml_content
    refute @handler.send(:xml_source?, "= render 'partial'")
  end

  def test_xml_source_with_empty_string
    refute @handler.send(:xml_source?, "")
  end

  def test_xml_source_with_nil
    refute @handler.send(:xml_source?, nil)
  end

  # --- render_compiled_source ---

  def test_render_compiled_source_with_valid_mjml
    mjml = "<mjml><mj-body><mj-section><mj-column><mj-text>Test</mj-text></mj-column></mj-section></mj-body></mjml>"
    result = MjmlRb::TemplateHandler.render_compiled_source(mjml, "test/template")
    assert_includes result, "Test"
    assert_includes result, "<!doctype html>"
  end

  def test_render_compiled_source_raises_on_strict_error
    invalid_mjml = "<html><body>not mjml</body></html>"
    assert_raises(RuntimeError) do
      MjmlRb::TemplateHandler.render_compiled_source(invalid_mjml, "test/template")
    end
  end

  def test_render_compiled_source_error_message_includes_template_path
    invalid_mjml = "<html><body>not mjml</body></html>"
    err = assert_raises(RuntimeError) do
      MjmlRb::TemplateHandler.render_compiled_source(invalid_mjml, "test/my_template")
    end
    assert_includes err.message, "test/my_template"
  end

  # --- render_partial_source ---

  def test_render_partial_source_returns_string
    result = MjmlRb::TemplateHandler.render_partial_source("Hello World")
    assert_equal "Hello World", result
  end

  def test_render_partial_source_with_nil
    result = MjmlRb::TemplateHandler.render_partial_source(nil)
    assert_equal "", result
  end

  # --- missing_rails_template_language_error ---

  def test_missing_rails_template_language_error_message
    msg = @handler.send(:missing_rails_template_language_error)
    assert_includes msg, "rails_template_language"
    assert_includes msg, "not configured"
  end

  # --- call with XML template ---

  def test_call_with_xml_template
    template = MockTemplate.new(
      source: "<mjml><mj-body></mj-body></mjml>",
      virtual_path: "layouts/email"
    )
    result = @handler.call(template)
    assert_includes result, "render_compiled_source"
    assert_includes result, "layouts/email"
  end

  def test_call_with_non_xml_template_without_language_configured
    MjmlRb.rails_template_language = nil
    template = MockTemplate.new(
      source: "= render 'partial'",
      virtual_path: "layouts/email"
    )
    result = @handler.call(template)
    # Should contain raise for missing template language
    assert_includes result, "rails_template_language"
  end

  # --- MjmlRb.rails_compiler_options ---

  def test_default_rails_compiler_options
    MjmlRb.rails_compiler_options = nil
    assert_equal({}, MjmlRb.rails_compiler_options)
  end

  def test_custom_rails_compiler_options
    original = MjmlRb.rails_compiler_options
    MjmlRb.rails_compiler_options = { validation_level: "soft" }
    assert_equal({ validation_level: "soft" }, MjmlRb.rails_compiler_options)
  ensure
    MjmlRb.rails_compiler_options = original
  end

  # --- MjmlRb.rails_template_language ---

  def test_rails_template_language_setter
    original = MjmlRb.rails_template_language
    MjmlRb.rails_template_language = "slim"
    assert_equal :slim, MjmlRb.rails_template_language
  ensure
    MjmlRb.rails_template_language = original
  end

  def test_rails_template_language_nil
    original = MjmlRb.rails_template_language
    MjmlRb.rails_template_language = nil
    assert_nil MjmlRb.rails_template_language
  ensure
    MjmlRb.rails_template_language = original
  end

  private

  class MockTemplate
    attr_reader :source, :virtual_path, :identifier

    def initialize(source:, virtual_path:)
      @source = source
      @virtual_path = virtual_path
      @identifier = virtual_path
    end

    def respond_to?(method, *args)
      method == :virtual_path || super
    end
  end
end
