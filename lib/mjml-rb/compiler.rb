require_relative "result"
require_relative "options"
require_relative "config_file"
require_relative "formatter"
require_relative "validator"
require_relative "parser"
require_relative "renderer"

module MjmlRb
  class Compiler
    DEFAULT_OPTIONS = Options::DEFAULTS
    VALID_OPTION_KEYS = Options::KEYS
    VALID_VALIDATION_LEVELS = %w[soft strict skip].freeze

    def initialize(options = {})
      @options = Options.normalize(options)
    end

    def mjml2html(mjml, options = {})
      compile(mjml, options)
    end

    def compile(mjml, options = {})
      do_compile(mjml, effective_options(options))
    end

    # Validation shares parsing and include diagnostics but never invokes a renderer.
    def validate(mjml, options = {})
      merged = effective_options(options)
      parsed = Parser.new.parse_result(mjml, merged)
      validation = Validator.new.validate(parsed, merged)
      Result.new(**validation, dependencies: parsed.dependencies)
    rescue Parser::ParseError => e
      Result.new(errors: [format_error(e.message, line: e.line, file: e.file)], dependencies: e.dependencies)
    end

    private

    def effective_options(options)
      explicit = Options.merge(@options, Options.normalize(options))
      config = ConfigFile.load(explicit[:mjml_config_path] || Dir.pwd)
      configured = explicit[:use_mjml_config_options] ? config.fetch(:options, {}) : {}
      Options.merge(DEFAULT_OPTIONS, Options.merge(configured, explicit))
    end

    def do_compile(mjml, merged)
      parsed = Parser.new.parse_result(mjml, merged)
      validation = Validator.new.validate(parsed, merged)
      return Result.new(**validation, dependencies: parsed.dependencies) if strict_validation_failed?(merged, validation[:errors])

      html = Renderer.new.render(parsed.ast, merged)
      Result.new(html: Formatter.new(merged).format(html), **validation, dependencies: parsed.dependencies)
    rescue Parser::ParseError => e
      Result.new(errors: [format_error(e.message, line: e.line, file: e.file)], dependencies: e.dependencies)
    rescue StandardError => e
      Result.new(errors: [format_error(e.message)], dependencies: parsed&.dependencies || [])
    end

    def strict_validation_failed?(options, validation_errors)
      options[:validation_level].to_s == "strict" && !validation_errors.empty?
    end

    def format_error(message, line: nil, file: nil)
      {
        line: line,
        message: message.to_s,
        tag_name: nil,
        formatted_message: message.to_s
      }.tap { |error| error[:file] = file if file }
    end
  end
end
