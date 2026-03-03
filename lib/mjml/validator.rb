require_relative "dependencies"
require_relative "parser"

module MjmlRb
  class Validator
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

      validate_allowed_children(node, errors)
      validate_required_attributes(node, errors)

      node.element_children.each { |child| walk(child, errors) }
    end

    def validate_allowed_children(node, errors)
      allowed = Dependencies::RULES[node.tag_name]
      return unless allowed

      node.element_children.each do |child|
        next if allowed_child?(child.tag_name, allowed)

        errors << error(
          "Element <#{child.tag_name}> is not allowed inside <#{node.tag_name}>",
          tag_name: child.tag_name
        )
      end
    end

    def validate_required_attributes(node, errors)
      required = REQUIRED_BY_TAG[node.tag_name] || []
      required.each do |attr|
        next if node.attributes.key?(attr)

        errors << error("Attribute `#{attr}` is required for <#{node.tag_name}>", tag_name: node.tag_name)
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

    def error(message, line: nil, tag_name: nil)
      {
        line: line,
        message: message,
        tag_name: tag_name,
        formatted_message: message
      }
    end
  end
end
