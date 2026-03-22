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

    def initialize(options = {})
      @options = DEFAULT_OPTIONS.merge(symbolize_keys(options))
      @parser = Parser.new
      @validator = Validator.new(parser: @parser)
      @renderer = Renderer.new
    end

    def mjml2html(mjml, options = {})
      compile(mjml, options)
    end

    def compile(mjml, options = {})
      merged = @options.merge(symbolize_keys(options))
      ast = @parser.parse(
        mjml,
        keep_comments: merged[:keep_comments],
        preprocessors: Array(merged[:preprocessors]),
        ignore_includes: merged[:ignore_includes],
        file_path: merged[:file_path],
        actual_path: merged[:actual_path]
      )

      validation = validate_if_needed(ast, merged)
      return Result.new(errors: validation[:errors], warnings: validation[:warnings]) if strict_validation_failed?(merged, validation[:errors])

      html = @renderer.render(ast, merged)
      Result.new(
        html: post_process(html, merged),
        errors: validation[:errors],
        warnings: validation[:warnings]
      )
    rescue Parser::ParseError => e
      Result.new(errors: [format_error(e.message, line: e.line)])
    rescue StandardError => e
      Result.new(errors: [format_error(e.message)])
    end

    private

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
