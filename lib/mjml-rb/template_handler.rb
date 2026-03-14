require "action_view"
require "action_view/template"
require "rails/version"

module MjmlRb
  class TemplateHandler
    def call(template, source = nil)
      if MjmlRb.rails_template_language.nil? && !xml_source?(template.source)
        return %(raise "MJML Rails template_language is not configured for non-XML templates. Supported values: nil, :erb, :slim, :haml")
      end

      compiled_source = compile_source(source, template)
      template_path = template.respond_to?(:virtual_path) ? template.virtual_path : template.identifier

      if /<mjml.*?>/i.match?(compiled_source)
        "::MjmlRb::TemplateHandler.render_compiled_source(begin;#{compiled_source};end, #{template_path.inspect})"
      else
        "::MjmlRb::TemplateHandler.render_partial_source(begin;#{compiled_source};end)"
      end
    end

    def self.render_compiled_source(mjml_source, template_path)
      mjml_result = ::MjmlRb::Compiler.new(::MjmlRb.rails_compiler_options || {}).compile(mjml_source.to_s)

      if mjml_result.errors.any?
        raise "MJML compilation failed for #{template_path}: #{mjml_result.errors.map { |error| error[:formatted_message] || error[:message] }.join(', ')}"
      end

      html = mjml_result.html.to_s
      html.respond_to?(:html_safe) ? html.html_safe : html
    end

    def self.render_partial_source(compiled_source)
      output = compiled_source.to_s
      output.respond_to?(:html_safe) ? output.html_safe : output
    end

    private

    def xml_source?(source)
      source.to_s.lstrip.start_with?("<")
    end

    def template_handler
      language = MjmlRb.rails_template_language
      raise "MJML Rails template_language is not configured for non-XML templates. Supported values: nil, :erb, :slim, :haml" if language.nil?

      handler = ActionView::Template.registered_template_handler(language)
      return handler if handler

      raise "MJML Rails template_language `#{language}` is not registered with ActionView. Make sure the matching Rails template handler is loaded."
    end

    def compile_source(source, template)
      if MjmlRb.rails_template_language.nil?
        template.source.inspect
      else
        template_handler.call(template, source)
      end
    end
  end
end
