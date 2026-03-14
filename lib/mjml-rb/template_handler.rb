module MjmlRb
  class TemplateHandler
    MJML_CAPTURE_DEPTH_IVAR = :@_mjml_rb_capture_depth
    LOCAL_ASSIGNS_IVAR = :@_mjml_rb_local_assigns
    TEMPLATE_ENGINES = {
      slim: {
        require: "slim",
        gem_name: "slim"
      },
      haml: {
        require: "haml",
        gem_name: "haml"
      }
    }.freeze

    class << self
      def call(template, source = nil)
        <<~RUBY
          ::MjmlRb::TemplateHandler.render(self, #{template.source.inspect}, #{template.identifier.inspect}, local_assigns)
        RUBY
      end

      def render(view_context, source, identifier, local_assigns = {})
        if capture_mode?(view_context)
          return mark_html_safe(render_source(view_context, source, local_assigns))
        end

        with_capture_mode(view_context) do
          mjml_source = render_source(view_context, source, local_assigns).to_s
          mjml_result = ::MjmlRb::Compiler.new(::MjmlRb.rails_compiler_options || {}).compile(mjml_source)

          if mjml_result.errors.any?
            raise "MJML compilation failed for #{identifier}: #{mjml_result.errors.map { |error| error[:formatted_message] || error[:message] }.join(', ')}"
          end

          mark_html_safe(mjml_result.html.to_s)
        end
      end

      private

      def render_source(view_context, source, local_assigns)
        language = ::MjmlRb.rails_template_language
        if language.nil?
          stripped_source = source.to_s.lstrip
          return source.to_s if stripped_source.start_with?("<")

          raise "MJML Rails template_language is not configured for non-XML templates. Supported values: nil, :erb, :slim, :haml"
        end

        case language
        when :erb
          render_erb_source(view_context, source.to_s, local_assigns)
        when :slim, :haml
          render_template_language_source(view_context, source.to_s, local_assigns, language)
        else
          raise "Unsupported MJML Rails template_language `#{language}`. Supported values: nil, :erb, :slim, :haml"
        end
      end

      def render_erb_source(view_context, source, local_assigns)
        require "erb"

        prepare_locals(view_context, local_assigns) do
          erb = ::ERB.new(source)
          erb.result(view_context.instance_eval { binding })
        end
      end

      def render_template_language_source(view_context, source, local_assigns, language)
        engine = TEMPLATE_ENGINES.fetch(language)
        require engine[:require]

        prepare_locals(view_context, local_assigns) do
          case language
          when :slim
            ::Slim::Template.new { source }.render(view_context, local_assigns.transform_keys(&:to_sym))
          when :haml
            if defined?(::Haml::Template)
              ::Haml::Template.new { source }.render(view_context, local_assigns.transform_keys(&:to_sym))
            else
              raise "MJML Rails template_language is set to :haml, but this Haml version does not expose Haml::Template"
            end
          end
        end
      rescue LoadError
        raise "MJML Rails template_language is set to :#{language}, but the `#{engine[:gem_name]}` gem is not available"
      end

      def prepare_locals(view_context, local_assigns)
        previous_local_assigns = view_context.instance_variable_get(LOCAL_ASSIGNS_IVAR)
        view_context.instance_variable_set(LOCAL_ASSIGNS_IVAR, local_assigns)
        define_local_assigns_reader(view_context)

        local_assigns.each do |name, value|
          define_local_reader(view_context, name, value)
        end

        yield
      ensure
        view_context.instance_variable_set(LOCAL_ASSIGNS_IVAR, previous_local_assigns)
      end

      def define_local_assigns_reader(view_context)
        singleton_class = class << view_context; self; end
        singleton_class.send(:define_method, :local_assigns) do
          instance_variable_get(LOCAL_ASSIGNS_IVAR) || {}
        end
      end

      def define_local_reader(view_context, name, value)
        singleton_class = class << view_context; self; end
        singleton_class.send(:define_method, name) do
          value
        end
      end

      def capture_mode?(view_context)
        view_context.instance_variable_get(MJML_CAPTURE_DEPTH_IVAR).to_i.positive?
      end

      def with_capture_mode(view_context)
        depth = view_context.instance_variable_get(MJML_CAPTURE_DEPTH_IVAR).to_i
        view_context.instance_variable_set(MJML_CAPTURE_DEPTH_IVAR, depth + 1)
        yield
      ensure
        next_depth = view_context.instance_variable_get(MJML_CAPTURE_DEPTH_IVAR).to_i - 1
        view_context.instance_variable_set(MJML_CAPTURE_DEPTH_IVAR, [next_depth, 0].max)
      end

      def mark_html_safe(value)
        value.respond_to?(:html_safe) ? value.html_safe : value
      end
    end
  end
end
