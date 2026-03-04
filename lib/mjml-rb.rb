require_relative "mjml-rb/version"
require_relative "mjml-rb/result"
require_relative "mjml-rb/ast_node"
require_relative "mjml-rb/dependencies"
require_relative "mjml-rb/parser"
require_relative "mjml-rb/renderer"
require_relative "mjml-rb/compiler"
require_relative "mjml-rb/validator"
require_relative "mjml-rb/migrator"
require_relative "mjml-rb/cli"

module MjmlRb
  class << self
    def mjml2html(mjml, options = {})
      Compiler.new(options).compile(mjml).to_h
    end

    alias to_html mjml2html
  end
end
