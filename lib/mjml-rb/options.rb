module MjmlRb
  # Shared by the library, JSON configuration and CLI. Canonicalization happens
  # before merging layers, so aliases never accidentally change precedence.
  module Options
    DEFAULTS = {
      beautify: false, minify: false, keep_comments: true,
      ignore_includes: true, printer_support: false, preprocessors: [],
      validation_level: "soft", file_path: ".", actual_path: ".",
      minify_options: {}, sanitize_styles: false,
      template_syntax: [{prefix: "{{", suffix: "}}"}, {prefix: "[[", suffix: "]]"}],
      allow_mixed_syntax: false, use_mjml_config_options: false
    }.freeze
    KEYS = (DEFAULTS.keys + %i[lang dir fonts include_path mjml_config_path juice_options juice_preserve_tags]).freeze

    def self.key(key)
      key.to_s.gsub(/([a-z\d])([A-Z])/, '\1_\2').tr("-", "_").downcase.to_sym
    end

    def self.normalize(options)
      raise ArgumentError, "Options must be an object" unless options.is_a?(Hash)

      result = options.each_with_object({}) do |(name, value), normalized|
        canonical = key(name)
        if canonical == :allow_includes
          canonical = :ignore_includes
          raise ArgumentError, "allowIncludes must be true or false" unless [true, false].include?(value)
          value = !value
        end
        if normalized.key?(canonical) && normalized[canonical] != value
          raise ArgumentError, "Conflicting values for #{canonical}"
        end
        normalized[canonical] = value
      end
      unknown = result.keys - KEYS
      raise ArgumentError, "Unknown option(s): #{unknown.join(', ')}" unless unknown.empty?
      if result.key?(:validation_level) && !%w[soft strict skip].include?(result[:validation_level].to_s)
        raise ArgumentError, "Invalid validation_level: #{result[:validation_level].inspect}"
      end
      %i[beautify minify keep_comments ignore_includes printer_support sanitize_styles allow_mixed_syntax use_mjml_config_options].each do |name|
        next unless result.key?(name)
        raise ArgumentError, "#{name} must be true or false" unless [true, false].include?(result[name])
      end
      %i[juice_options juice_preserve_tags].each do |name|
        next unless result.key?(name)
        raise ArgumentError, "Unsupported option: #{name}; the Ruby CSS inliner does not implement Juice options" unless result[name].nil? || result[name] == {}
      end
      if result.key?(:include_path) && !(result[:include_path].is_a?(String) || (result[:include_path].is_a?(Array) && result[:include_path].all? { |p| p.is_a?(String) }))
        raise ArgumentError, "include_path must be a string or an array of strings"
      end
      if result.key?(:preprocessors) && !(result[:preprocessors].is_a?(Array) && result[:preprocessors].all? { |processor| processor.respond_to?(:call) })
        raise ArgumentError, "preprocessors must be an array of callables"
      end
      if result.key?(:template_syntax)
        syntaxes = result[:template_syntax]
        valid = syntaxes.is_a?(Array) && syntaxes.all? do |syntax|
          syntax.is_a?(Hash) && %i[prefix suffix].all? do |part|
            value = syntax[part] || syntax[part.to_s]
            value.is_a?(String) && !value.empty?
          end
        end
        raise ArgumentError, "template_syntax must be an array of non-empty prefix/suffix objects" unless valid
      end
      if result.key?(:minify_options)
        value = result[:minify_options]
        raise ArgumentError, "minify_options must be an object" unless value.is_a?(Hash)
        result[:minify_options] = value.each_with_object({}) do |(name, setting), memo|
          canonical = name.to_s.gsub(/[^a-z]/i, "").downcase
          raise ArgumentError, "Unsupported minify_options key: #{name}" unless canonical == "minifycss"
          raise ArgumentError, "minifyCss must be true or false" unless [true, false].include?(setting)
          raise ArgumentError, "Conflicting minifyCss values" if memo.key?(:minify_css) && memo[:minify_css] != setting
          memo[:minify_css] = setting
        end
      end
      result
    end

    def self.merge(base, overrides)
      base.merge(overrides).merge(minify_options: (base[:minify_options] || {}).merge(overrides[:minify_options] || {}))
    end
  end
end
