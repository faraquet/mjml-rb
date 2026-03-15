require "json"

module MjmlRb
  class ConfigFile
    DEFAULT_NAME = ".mjmlrc"

    def self.load(dir = Dir.pwd)
      path = File.join(dir, DEFAULT_NAME)
      return {} unless File.exist?(path)

      raw = JSON.parse(File.read(path))
      config = {}

      if raw["packages"].is_a?(Array)
        raw["packages"].each do |pkg_path|
          resolved = File.expand_path(pkg_path, dir)
          require resolved
        end
        config[:packages_loaded] = raw["packages"]
      end

      if raw["options"].is_a?(Hash)
        config[:options] = raw["options"].each_with_object({}) do |(k, v), memo|
          memo[k.to_s.tr("-", "_").to_sym] = v
        end
      end

      config
    rescue JSON::ParserError => e
      warn "WARNING: Failed to parse #{path}: #{e.message}"
      {}
    end
  end
end
