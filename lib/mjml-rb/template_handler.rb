module MjmlRb
  class TemplateHandler
    class << self
      def call(template, source = nil)
        <<~RUBY
          mjml_compiler_options = (::MjmlRb.rails_compiler_options || {}).dup
          mjml_result = ::MjmlRb::Compiler.new(mjml_compiler_options).compile(#{template.source.inspect})
          if mjml_result.errors.any?
            raise "MJML compilation failed for #{template.identifier}: \#{mjml_result.errors.map { |error| error[:formatted_message] || error[:message] }.join(', ')}"
          end
          mjml_html = mjml_result.html.to_s
          mjml_html.respond_to?(:html_safe) ? mjml_html.html_safe : mjml_html
        RUBY
      end
    end
  end
end
