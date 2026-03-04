require_relative "mjml_rb/version"
require_relative "mjml_rb/result"
require_relative "mjml_rb/ast_node"
require_relative "mjml_rb/dependencies"
require_relative "mjml_rb/parser"
require_relative "mjml_rb/renderer"
require_relative "mjml_rb/compiler"
require_relative "mjml_rb/validator"
require_relative "mjml_rb/migrator"
require_relative "mjml_rb/cli"

module MjmlRb
  class << self
    def mjml2html(mjml, options = {})
      Compiler.new(options).compile(mjml).to_h
    end

    alias to_html mjml2html
  end
end
