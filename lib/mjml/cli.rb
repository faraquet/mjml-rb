require "json"
require "optparse"
require "pathname"
require "time"

require_relative "compiler"
require_relative "migrator"
require_relative "version"

module MJML
  class CLI
    class CLIError < StandardError; end

    def initialize(stdout: $stdout, stderr: $stderr)
      @stdout = stdout
      @stderr = stderr
    end

    def run(argv = ARGV)
      raw_argv = argv.dup
      argv, inline_config = extract_inline_config(raw_argv)
      options = default_options

      parser = option_parser(options, inline_config)
      parser.parse!(argv)
      options[:positional] = argv

      input_mode, input_values = resolve_input(options)
      output_mode = resolve_output(options)
      config = options[:config]

      case input_mode
      when :watch
        watch_files(input_values, config, options[:output])
        0
      when :stdin
        mjml = $stdin.read
        processed = process_input({ file: nil, mjml: mjml }, input_mode, config)
        emit_results([processed], output_mode, options)
      else
        inputs = load_inputs(input_values)
        raise CLIError, "No input files found" if inputs.empty?

        processed = inputs.map { |input| process_input(input, input_mode, config) }
        emit_results(processed, output_mode, options)
      end
    rescue CLIError => e
      @stderr.puts("\nCommand line error:")
      @stderr.puts(e.message)
      1
    rescue OptionParser::ParseError => e
      @stderr.puts(e.message)
      1
    end

    private

    def default_options
      {
        read: [],
        migrate: [],
        validate: [],
        watch: [],
        stdin: false,
        stdout: false,
        output: nil,
        no_stdout_file_comment: false,
        config: {
          beautify: true,
          minify: false
        }
      }
    end

    def option_parser(options, inline_config)
      OptionParser.new do |opts|
        opts.banner = "Usage: mjml [options] [files]"

        opts.on("-r", "--read FILES", Array, "Compile MJML files") { |v| options[:read].concat(v) }
        opts.on("-m", "--migrate FILES", Array, "Migrate MJML3 files") { |v| options[:migrate].concat(v) }
        opts.on("-v", "--validate FILES", Array, "Validate MJML files") { |v| options[:validate].concat(v) }
        opts.on("-w", "--watch FILES", Array, "Watch and compile files when modified") { |v| options[:watch].concat(v) }
        opts.on("-i", "--stdin", "Read MJML from stdin") { options[:stdin] = true }
        opts.on("-s", "--stdout", "Output HTML to stdout") { options[:stdout] = true }
        opts.on("-o", "--output PATH", "Output file or directory") { |v| options[:output] = v }
        opts.on("-c", "--config KEY=VALUE", "Compiler config key/value") do |entry|
          key, value = parse_key_value(entry)
          options[:config][normalize_key(key)] = parse_typed_value(value)
        end
        opts.on("--noStdoutFileComment", "Skip file comment header on stdout") do
          options[:no_stdout_file_comment] = true
        end
        opts.on("-V", "--version", "Show version") do
          @stdout.puts("mjml-ruby #{MJML::VERSION}")
          raise SystemExit, 0
        end
        opts.on("-h", "--help", "Show help") do
          @stdout.puts(opts)
          raise SystemExit, 0
        end
      end.tap do
        inline_config.each do |key, value|
          options[:config][normalize_key(key)] = value
        end
      end
    end

    def extract_inline_config(argv)
      config = {}
      remaining = []

      argv.each do |arg|
        if arg.start_with?("--config.")
          key, value = parse_key_value(arg.sub("--config.", ""))
          config[key] = parse_typed_value(value)
        else
          remaining << arg
        end
      end

      [remaining, config]
    end

    def parse_key_value(input)
      key, value = input.split("=", 2)
      raise CLIError, "Invalid config entry: #{input}" if key.to_s.empty?
      [key, value]
    end

    def parse_typed_value(value)
      return true if value.nil?
      return false if value == "false"
      return true if value == "true"
      return value.to_i if value.match?(/\A-?\d+\z/)
      return value.to_f if value.match?(/\A-?\d+\.\d+\z/)

      begin
        JSON.parse(value)
      rescue JSON::ParserError
        value
      end
    end

    def normalize_key(key)
      key.to_s.tr("-", "_").to_sym
    end

    def resolve_input(options)
      inputs = {}
      inputs[:read] = options[:read] unless options[:read].empty?
      inputs[:migrate] = options[:migrate] unless options[:migrate].empty?
      inputs[:validate] = options[:validate] unless options[:validate].empty?
      inputs[:watch] = options[:watch] unless options[:watch].empty?
      inputs[:stdin] = true if options[:stdin]
      inputs[:read] = options[:positional] unless options[:positional].empty?

      raise CLIError, "No input argument received" if inputs.empty?
      raise CLIError, "Too many input arguments received" if inputs.keys.size > 1

      key = inputs.keys.first
      [key, inputs[key]]
    end

    def resolve_output(options)
      outputs = []
      outputs << :output if !options[:output].nil?
      outputs << :stdout if options[:stdout]

      raise CLIError, "Too many output arguments received" if outputs.size > 1
      outputs.first || :stdout
    end

    def load_inputs(patterns)
      expand_paths(Array(patterns)).map { |path| { file: path, mjml: File.read(path) } }
    rescue Errno::ENOENT => e
      raise CLIError, "Cannot read file: #{e.message}"
    end

    def expand_paths(patterns)
      paths = patterns.flat_map { |pattern| Dir.glob(pattern, File::FNM_EXTGLOB) }
      paths.uniq.select { |path| File.file?(path) }
    end

    def process_input(input, mode, config)
      case mode
      when :migrate
        html = Migrator.new.migrate(input[:mjml])
        { file: input[:file], compiled: Result.new(html: html) }
      when :validate
        compiler = Compiler.new(config.merge(validation_level: "strict"))
        { file: input[:file], compiled: compiler.compile(input[:mjml]) }
      else
        compiler = Compiler.new(config)
        { file: input[:file], compiled: compiler.compile(input[:mjml]) }
      end
    end

    def emit_results(processed, output_mode, options)
      processed.each { |item| emit_errors(item[:compiled], item[:file]) }

      invalid = processed.any? { |item| !item[:compiled].errors.empty? }
      if options[:validate].any? && invalid
        raise CLIError, "Validation failed"
      end

      case output_mode
      when :stdout
        print_stdout(processed, !options[:no_stdout_file_comment])
      when :output
        write_outputs(processed, options[:output])
      else
        raise CLIError, "Command line error: No output option available"
      end

      invalid ? 2 : 0
    end

    def emit_errors(result, file)
      return if result.errors.empty?
      result.errors.each do |error|
        prefix = file ? "File: #{file}\n" : ""
        @stderr.puts("#{prefix}#{error[:formatted_message] || error[:message]}")
      end
    end

    def print_stdout(processed, add_file_comment)
      processed.each do |entry|
        output = +""
        output << "<!-- FILE: #{entry[:file]} -->\n" if add_file_comment
        output << entry[:compiled].html
        output << "\n"
        @stdout.write(output)
      end
    end

    def write_outputs(processed, output_path)
      if processed.size > 1 && !directory?(output_path) && output_path != ""
        raise CLIError, "Multiple input files require an existing output directory or empty output path"
      end

      processed.each do |entry|
        output_name = guess_output_name(entry[:file], output_path)
        dir = File.dirname(output_name)
        raise CLIError, "Output directory does not exist for path: #{output_name}" unless directory?(dir)

        File.write(output_name, entry[:compiled].html)
      end
    end

    def guess_output_name(input_file, output_path)
      return replace_extension(File.basename(input_file)) if output_path.to_s.empty?
      return File.join(output_path, replace_extension(File.basename(input_file))) if directory?(output_path)

      output_path
    end

    def replace_extension(path)
      return path.sub(/\.mjml\z/, ".html") if path.end_with?(".mjml")
      return path if path.match?(/\.[^\/]+\z/)

      "#{path}.html"
    end

    def directory?(path)
      File.directory?(File.expand_path(path.to_s))
    rescue StandardError
      false
    end

    def watch_files(patterns, config, output_path)
      files = expand_paths(Array(patterns))
      raise CLIError, "No input files found" if files.empty?
      if files.size > 1 && !directory?(output_path) && output_path != ""
        raise CLIError, "Need an output directory when watching multiple files"
      end

      state = files.each_with_object({}) { |path, memo| memo[path] = file_mtime(path) }
      @stdout.puts("Watching #{files.size} file(s)...")

      loop do
        files.each do |file|
          current = file_mtime(file)
          next if current.nil? || current <= state[file]

          state[file] = current
          begin
            input = { file: file, mjml: File.read(file) }
            processed = process_input(input, :read, config)
            emit_results([processed], :output, output: output_path, no_stdout_file_comment: true, validate: [])
            @stdout.puts("#{file} - Successfully compiled")
          rescue StandardError => e
            @stderr.puts("#{file} - Error while compiling file: #{e.message}")
          end
        end
        sleep 0.5
      end
    end

    def file_mtime(path)
      File.mtime(path)
    rescue StandardError
      nil
    end
  end
end
