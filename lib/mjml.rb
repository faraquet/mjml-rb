require_relative "mjml/version"
require_relative "mjml/result"
require_relative "mjml/ast_node"
require_relative "mjml/dependencies"
require_relative "mjml/parser"
require_relative "mjml/renderer"
require_relative "mjml/compiler"
require_relative "mjml/validator"
require_relative "mjml/migrator"
require_relative "mjml/cli"

module MJML
  class << self
    def mjml2html(mjml, options = {})
      Compiler.new(options).compile(mjml).to_h
    end

    alias to_html mjml2html
  end
end
