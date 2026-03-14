require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "nokogiri"

require_relative "../lib/mjml-rb"

RAILS_INTEGRATION_AVAILABLE = begin
  require "action_view"
  require "rails"
  true
rescue LoadError
  false
end

class RailsIntegrationTest < Minitest::Test
  class SlimTestHandler
    def call(template, source = nil)
      require "slim"

      ::Slim::Engine.new.call(source || template.source)
    end
  end

  if !RAILS_INTEGRATION_AVAILABLE
    def test_rails_dependencies_are_optional
      skip "action_view and rails are not installed in this environment"
    end
  else
    def setup
      @original_rails_compiler_options = MjmlRb.rails_compiler_options
      @original_rails_template_language = MjmlRb.rails_template_language
      @original_mjml_handler = ActionView::Template.handler_for_extension(:mjml)
      @original_slim_handler = ActionView::Template.registered_template_handler(:slim)
      MjmlRb.rails_compiler_options = {validation_level: "strict"}
      MjmlRb.rails_template_language = nil
      ActionView::Template.register_template_handler(:slim, SlimTestHandler.new)
      MjmlRb.register_action_view_template_handler!
    end

    def teardown
      MjmlRb.rails_compiler_options = @original_rails_compiler_options
      MjmlRb.rails_template_language = @original_rails_template_language
      ActionView::Template.unregister_template_handler(:mjml)
      ActionView::Template.register_template_handler(:mjml, @original_mjml_handler) if @original_mjml_handler
      ActionView::Template.unregister_template_handler(:slim)
      ActionView::Template.register_template_handler(:slim, @original_slim_handler) if @original_slim_handler
    end

    def test_registers_mjml_template_handler_with_action_view
      assert_instance_of MjmlRb::TemplateHandler, ActionView::Template.handler_for_extension(:mjml)
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

    def test_renders_slim_mjml_template_with_nested_partials
      MjmlRb.rails_template_language = :slim

      with_templates(
        "welcome.html.mjml" => <<~SLIM,
          mjml[owa="desktop"]
            mj-body
              = render "shared/greeting", message: "Hello from Slim"
        SLIM
        "shared/_greeting.html.mjml" => <<~SLIM
          mj-section
            mj-column
              mj-text = message
        SLIM
      ) do |view|
        html = view.render(template: "welcome")

        assert_includes html, "Hello from Slim"
        refute_includes html, "&lt;mj-section"

        document = Nokogiri::HTML(html)
        assert_equal "Hello from Slim", document.at_css("div")&.text.to_s.strip
      end
    end

    def test_slim_partial_can_access_local_assigns
      MjmlRb.rails_template_language = :slim

      with_templates(
        "welcome.html.mjml" => <<~SLIM,
          mjml
            mj-body
              = render "shared/greeting", message: "Hello from locals"
        SLIM
        "shared/_greeting.html.mjml" => <<~SLIM
          - text = local_assigns.fetch(:message)
          mj-section
            mj-column
              mj-text = text
        SLIM
      ) do |view|
        html = view.render(template: "welcome")

        assert_includes html, "Hello from locals"
      end
    end

    def test_renders_erb_mjml_template_with_nested_partials
      MjmlRb.rails_template_language = :erb

      with_templates(
        "welcome.html.mjml" => <<~ERB,
          <mjml>
            <mj-body>
              <%= render "shared/greeting", message: "Hello from ERB" %>
            </mj-body>
          </mjml>
        ERB
        "shared/_greeting.html.mjml" => <<~ERB
          <mj-section>
            <mj-column>
              <mj-text><%= message %></mj-text>
            </mj-column>
          </mj-section>
        ERB
      ) do |view|
        html = view.render(template: "welcome")

        assert_includes html, "Hello from ERB"
        refute_includes html, "&lt;mj-section"

        document = Nokogiri::HTML(html)
        assert_equal "Hello from ERB", document.at_css("div")&.text.to_s.strip
      end
    end

    def test_non_xml_template_requires_explicit_template_language
      with_template("welcome.html.mjml", <<~SLIM) do |view|
        mjml
          mj-body
            mj-section
              mj-column
                mj-text Hello from Slim
      SLIM
        error = assert_raises(ActionView::Template::Error) do
          view.render(template: "welcome")
        end

        assert_includes error.cause&.message.to_s, "template_language"
        assert_includes error.cause&.message.to_s, "Supported values: nil, :erb, :slim, :haml"
      end
    end

    def test_haml_requires_haml_gem_when_enabled
      MjmlRb.rails_template_language = :haml

      with_template("welcome.html.mjml", <<~HAML) do |view|
        %mjml
          %mj-body
            %mj-section
              %mj-column
                %mj-text Hello from Haml
      HAML
        error = assert_raises(ActionView::Template::Error) do
          view.render(template: "welcome")
        end

        assert_includes error.cause&.message.to_s, "template_language `haml` is not registered"
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
      with_templates(name => contents) do |view|
        yield view
      end
    end

    def with_templates(templates)
      Dir.mktmpdir do |dir|
        templates.each do |name, contents|
          full_path = File.join(dir, name)
          FileUtils.mkdir_p(File.dirname(full_path))
          File.write(full_path, contents)
        end
        view = ActionView::Base.with_empty_template_cache.with_view_paths(dir)
        yield view
      end
    end
  end
end
