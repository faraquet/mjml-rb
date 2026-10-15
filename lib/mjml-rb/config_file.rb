require "json"
require_relative "options"

module MjmlRb
  class ConfigFile
    DEFAULT_NAME = ".mjmlconfig"
    NAMES = [DEFAULT_NAME, ".mjmlrc", ".mjmlconfig.js"].freeze

    class ConfigError < StandardError
      attr_reader :path

      def initialize(message, path:)
        @path = path
        super(message)
      end
    end

    def self.load(location = Dir.pwd)
      path = if File.directory?(location)
               NAMES.map { |name| File.join(location, name) }.find { |candidate| File.file?(candidate) }
             else
               location
             end
      return {} unless path
      if path.end_with?(".js")
        raise ConfigError.new("JavaScript MJML configuration is unsupported; use JSON and register Ruby components", path: path)
      end

      raw = JSON.parse(File.read(path))
      raise ArgumentError, "Configuration root must be an object" unless raw.is_a?(Hash)
      config = {}
      if raw.key?("options") && !raw["options"].is_a?(Hash)
        raise ArgumentError, "Configuration options must be an object"
      end
      config[:options] = Options.normalize(raw["options"]) if raw["options"]
      if raw["packages"].is_a?(Array)
        raw["packages"].each do |package|
          unless package.is_a?(String) && package.end_with?(".rb")
            raise ArgumentError, "JavaScript component packages are unsupported; use a Ruby .rb component file"
          end
          require File.expand_path(package, File.dirname(path))
        end
        config[:packages_loaded] = raw["packages"]
      end
      config
    rescue JSON::ParserError => e
      raise ConfigError.new("Failed to parse #{path}: #{e.message}", path: path)
    rescue ArgumentError, SystemCallError, LoadError => e
      raise ConfigError.new("Failed to load #{path}: #{e.message}", path: path)
    end
  end
end
