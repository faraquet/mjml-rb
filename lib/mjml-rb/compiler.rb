require_relative "result"
require_relative "validator"
require_relative "parser"
require_relative "renderer"

module MjmlRb
  class Compiler
    DEFAULT_OPTIONS = {
      beautify: false,
      minify: false,
      keep_comments: true,
      ignore_includes: false,
      printer_support: false,
      preprocessors: [],
      validation_level: "soft",
      file_path: ".",
      actual_path: "."
    }.freeze

    # Additional option keys accepted by the renderer but not in DEFAULT_OPTIONS.
    EXTRA_VALID_KEYS = %i[lang dir fonts printerSupport].freeze

    VALID_OPTION_KEYS = (DEFAULT_OPTIONS.keys + EXTRA_VALID_KEYS).freeze

    VALID_VALIDATION_LEVELS = %w[soft strict skip].freeze

    def initialize(options = {})
      normalized = symbolize_keys(options)
      validate_options!(normalized)
      @options = DEFAULT_OPTIONS.merge(normalized)
      @parser = Parser.new
      @validator = Validator.new(parser: @parser)
      @renderer = Renderer.new
    end

    def mjml2html(mjml, options = {})
      compile(mjml, options)
    end

    def compile(mjml, options = {})
      normalized = symbolize_keys(options)
      validate_options!(normalized)
      merged = @options.merge(normalized)

      do_compile(mjml, merged)
    end

    private

    def do_compile(mjml, merged)
      ast = @parser.parse(
        mjml,
        keep_comments: merged[:keep_comments],
        preprocessors: Array(merged[:preprocessors]),
        ignore_includes: merged[:ignore_includes],
        file_path: merged[:file_path],
        actual_path: merged[:actual_path]
      )

      include_issues = format_include_errors(@parser.include_errors)
      validation = validate_if_needed(ast, merged)
      include_validation = classify_include_issues(include_issues, merged)

      all_errors = validation[:errors] + include_validation[:errors]
      all_warnings = validation[:warnings] + include_validation[:warnings]

      return Result.new(errors: all_errors, warnings: all_warnings) if strict_validation_failed?(merged, all_errors)

      html = @renderer.render(ast, merged)
      Result.new(
        html: post_process(html, merged),
        errors: all_errors,
        warnings: all_warnings
      )
    rescue Parser::ParseError => e
      Result.new(errors: [format_error(e.message, line: e.line)])
    rescue StandardError => e
      Result.new(errors: [format_error(e.message)])
    end

    def validate_options!(options)
      unknown = options.keys - VALID_OPTION_KEYS
      unless unknown.empty?
        raise ArgumentError, "Unknown option(s): #{unknown.join(', ')}. Valid options are: #{VALID_OPTION_KEYS.join(', ')}"
      end

      if options.key?(:validation_level)
        level = options[:validation_level].to_s
        unless VALID_VALIDATION_LEVELS.include?(level)
          raise ArgumentError, "Invalid validation_level: #{level.inspect}. Must be one of: #{VALID_VALIDATION_LEVELS.join(', ')}"
        end
      end
    end

    def validate_if_needed(ast, options)
      return { errors: [], warnings: [] } if options[:validation_level].to_s == "skip"
      @validator.validate(ast, options)
    end

    def strict_validation_failed?(options, validation_errors)
      options[:validation_level].to_s == "strict" && !validation_errors.empty?
    end

    def post_process(html, options)
      output = html.to_s.dup
      output = strip_comments(output) unless options[:keep_comments]
      output = beautify(output) if truthy?(options[:beautify])
      output = minify(output) if truthy?(options[:minify])
      output
    end

    def strip_comments(html)
      html.gsub(/<!--.*?-->/m, "")
    end

    def beautify(html)
      # Keep it deterministic without external formatters.
      html.gsub(/>\s*</, ">\n<")
    end

    def minify(html)
      html.gsub(/>\s+</, "><").gsub(/\s{2,}/, " ").strip
    end

    def truthy?(value)
      return value if value == true || value == false
      !(%w[false 0 no off].include?(value.to_s.strip.downcase))
    end

    def symbolize_keys(hash)
      hash.each_with_object({}) do |(k, v), memo|
        memo[k.to_s.tr("-", "_").to_sym] = v
      end
    end

    def format_include_errors(include_errors)
      Array(include_errors).map do |ie|
        format_error(ie[:message], line: ie[:line])
      end
    end

    def classify_include_issues(issues, options)
      return { errors: [], warnings: [] } if issues.empty?

      level = options[:validation_level].to_s
      if level == "strict"
        { errors: issues, warnings: [] }
      else
        { errors: [], warnings: issues }
      end
    end

    def format_error(message, line: nil)
      {
        line: line,
        message: message.to_s,
        tag_name: nil,
        formatted_message: message.to_s
      }
    end
  end
end
