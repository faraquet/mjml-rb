require_relative "dependencies"
require_relative "parser"

module MjmlRb
  class Validator
    GLOBAL_ALLOWED_ATTRIBUTES = %w[css-class mj-class].freeze

    REQUIRED_BY_TAG = {
      "mj-image" => %w[src],
      "mj-font" => %w[name href],
      "mj-include" => %w[path]
    }.freeze

    def initialize(parser: Parser.new)
      @parser = parser
    end

    def validate(mjml_or_ast, options = {})
      root = mjml_or_ast.is_a?(AstNode) ? mjml_or_ast : parse_ast(mjml_or_ast, options)
      return [error("Root element must be <mjml>", tag_name: root&.tag_name)] unless root&.tag_name == "mjml"

      errors = []
      errors << error("Missing <mj-body>", tag_name: "mjml") unless root.element_children.any? { |c| c.tag_name == "mj-body" }
      walk(root, errors)
      errors
    rescue Parser::ParseError => e
      [error(e.message, line: e.line)]
    end

    private

    def parse_ast(mjml, options)
      @parser.parse(
        mjml,
        keep_comments: options.fetch(:keep_comments, false),
        preprocessors: options.fetch(:preprocessors, []),
        ignore_includes: options.fetch(:ignore_includes, false),
        file_path: options.fetch(:file_path, "."),
        actual_path: options.fetch(:actual_path, ".")
      )
    end

    def walk(node, errors)
      return unless node.element?

      validate_known_tag(node, errors)
      validate_allowed_children(node, errors)
      validate_required_attributes(node, errors)
      validate_supported_attributes(node, errors)
      validate_attribute_types(node, errors)

      return if MjmlRb.component_registry.ending_tags.include?(node.tag_name)

      node.element_children.each { |child| walk(child, errors) }
    end

    def validate_known_tag(node, errors)
      return if known_tag?(node.tag_name)

      errors << error(
        "Element <#{node.tag_name}> doesn't exist or is not registered",
        tag_name: node.tag_name, line: node.line, file: node.file
      )
    end

    def validate_allowed_children(node, errors)
      # Ending-tag components treat content as raw HTML; REXML still parses
      # children structurally, so skip child validation for those tags.
      return if MjmlRb.component_registry.ending_tags.include?(node.tag_name)

      allowed = MjmlRb.component_registry.dependency_rules[node.tag_name]
      return unless allowed

      node.element_children.each do |child|
        next if allowed_child?(child.tag_name, allowed)

        errors << error(
          "Element <#{child.tag_name}> is not allowed inside <#{node.tag_name}>",
          tag_name: child.tag_name, line: child.line, file: child.file
        )
      end
    end

    def validate_required_attributes(node, errors)
      required = REQUIRED_BY_TAG[node.tag_name] || []
      required.each do |attr|
        next if node.attributes.key?(attr)

        errors << error("Attribute `#{attr}` is required for <#{node.tag_name}>",
                        tag_name: node.tag_name, line: node.line, file: node.file)
      end
    end

    def validate_supported_attributes(node, errors)
      allowed_attributes = allowed_attributes_for(node.tag_name)
      return if allowed_attributes.empty?

      node.attributes.each_key do |attribute_name|
        next if allowed_attributes.key?(attribute_name)
        next if GLOBAL_ALLOWED_ATTRIBUTES.include?(attribute_name)

        errors << error("Attribute `#{attribute_name}` is not allowed for <#{node.tag_name}>",
                        tag_name: node.tag_name, line: node.line, file: node.file)
      end
    end

    def validate_attribute_types(node, errors)
      allowed_attributes = allowed_attributes_for(node.tag_name)
      return if allowed_attributes.empty?

      node.attributes.each do |attribute_name, attribute_value|
        next if GLOBAL_ALLOWED_ATTRIBUTES.include?(attribute_name)

        expected_type = allowed_attributes[attribute_name]
        next unless expected_type
        next if valid_attribute_value?(attribute_value, expected_type)

        errors << error(
          "Attribute `#{attribute_name}` on <#{node.tag_name}> has invalid value `#{attribute_value}` for type `#{expected_type}`",
          tag_name: node.tag_name, line: node.line, file: node.file
        )
      end
    end

    def allowed_attributes_for(tag_name)
      component_class = component_class_for_tag(tag_name)
      return {} unless component_class

      if component_class.respond_to?(:allowed_attributes_for)
        component_class.allowed_attributes_for(tag_name)
      else
        component_class.allowed_attributes
      end
    end

    def component_class_for_tag(tag_name)
      MjmlRb.component_registry.component_class_for_tag(tag_name)
    end

    def known_tag?(tag_name)
      tag_name == "mjml" || !component_class_for_tag(tag_name).nil?
    end

    def valid_attribute_value?(value, expected_type)
      return true if value.nil?

      case expected_type
      when "string"
        true
      when "boolean"
        %w[true false].include?(value)
      when "integer"
        value.match?(/\A-?\d+\z/)
      when "color"
        color?(value)
      when /\Aenum\((.+)\)\z/
        Regexp.last_match(1).split(",").map(&:strip).include?(value)
      when /\AunitWithNegative\((.+)\)(?:\{(\d+),(\d+)\})?\z/
        units = Regexp.last_match(1).split(",", -1).map(&:strip)
        min_count = Regexp.last_match(2)&.to_i || 1
        max_count = Regexp.last_match(3)&.to_i || 1
        unit_values?(value, units, min_count: min_count, max_count: max_count)
      when /\Aunit\((.+)\)(?:\{(\d+),(\d+)\})?\z/
        units = Regexp.last_match(1).split(",", -1).map(&:strip)
        min_count = Regexp.last_match(2)&.to_i || 1
        max_count = Regexp.last_match(3)&.to_i || 1
        unit_values?(value, units, min_count: min_count, max_count: max_count)
      else
        true
      end
    end

    def color?(value)
      value.match?(/\A#[0-9a-fA-F]{3,8}\z/) ||
        value.match?(/\Argb[a]?\([^)]+\)\z/i) ||
        value.match?(/\Ahsl[a]?\([^)]+\)\z/i) ||
        value.match?(/\A[a-z]+\z/i)
    end

    def unit_values?(value, units, min_count:, max_count:)
      parts = value.to_s.strip.split(/\s+/)
      return false if parts.empty? || parts.size < min_count || parts.size > max_count

      parts.all? { |part| unit_value?(part, units) }
    end

    def unit_value?(value, units)
      return true if value.match?(/\A0(?:\.0+)?\z/)

      units.any? do |unit|
        if unit.empty?
          value.match?(/\A-?\d+(?:\.\d+)?\z/)
        else
          value == unit || value.match?(/\A-?\d+(?:\.\d+)?#{Regexp.escape(unit)}\z/)
        end
      end
    end

    def allowed_child?(tag_name, allowed_patterns)
      allowed_patterns.any? do |pattern|
        case pattern
        when Regexp then pattern.match?(tag_name)
        else pattern == tag_name
        end
      end
    end

    def error(message, line: nil, tag_name: nil, file: nil)
      location = [
        ("line #{line}" if line),
        ("in #{file}" if file)
      ].compact.join(", ")

      {
        line: line,
        file: file,
        message: message,
        tag_name: tag_name,
        formatted_message: location.empty? ? message : "#{message} (#{location})"
      }
    end
  end
end
