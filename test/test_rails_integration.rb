require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "action_view"
require "rails"
require "nokogiri"

require_relative "../lib/mjml-rb"

class RailsIntegrationTest < Minitest::Test
  def setup
    @original_rails_compiler_options = MjmlRb.rails_compiler_options
    MjmlRb.rails_compiler_options = {validation_level: "strict"}
    MjmlRb.register_action_view_template_handler!
  end

  def teardown
    MjmlRb.rails_compiler_options = @original_rails_compiler_options
  end

  def test_registers_mjml_template_handler_with_action_view
    assert_equal MjmlRb::TemplateHandler, ActionView::Template.handler_for_extension(:mjml)
  end

  def test_renders_html_mjml_template_through_action_view
    with_template("welcome.html.mjml", <<~MJML) do |view|
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text>Hello from Rails</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
      html = view.render(template: "welcome")

      assert_kind_of ActiveSupport::SafeBuffer, html
      assert_includes html, "Hello from Rails"

      document = Nokogiri::HTML(html)
      assert_equal "Hello from Rails", document.at_css("div")&.text.to_s.strip
    end
  end

  def test_raises_template_error_for_invalid_mjml
    with_template("broken.html.mjml", <<~MJML) do |view|
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-image alt="missing src" />
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    MJML
      error = assert_raises(ActionView::Template::Error) do
        view.render(template: "broken")
      end

      assert_includes error.cause&.message.to_s, "MJML compilation failed"
      assert_includes error.cause&.message.to_s, "Attribute `src` is required for <mj-image>"
    end
  end

  private

  def with_template(name, contents)
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, name), contents)
      view = ActionView::Base.with_empty_template_cache.with_view_paths(dir)
      yield view
    end
  end
end
