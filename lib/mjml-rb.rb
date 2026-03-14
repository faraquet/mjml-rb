require_relative "mjml-rb/version"
require_relative "mjml-rb/result"
require_relative "mjml-rb/ast_node"
require_relative "mjml-rb/dependencies"
require_relative "mjml-rb/parser"
require_relative "mjml-rb/renderer"
require_relative "mjml-rb/compiler"
require_relative "mjml-rb/validator"
require_relative "mjml-rb/cli"

module MjmlRb
  # Print an experimental warning once at load time unless suppressed.
  # Suppress by setting the environment variable MJML_RB_NO_WARN=1.
  warn <<~WARNING unless ENV["MJML_RB_NO_WARN"] == "1"
    WARNING: mjml-rb #{VERSION} is EXPERIMENTAL software.
    It is an unofficial Ruby port of MJML, not affiliated with or endorsed by
    the MJML team. Output may differ from the reference npm renderer. Not all
    components are fully implemented. Use in production at your own risk.
    Set MJML_RB_NO_WARN=1 to suppress this message.
  WARNING

  class << self
    def mjml2html(mjml, options = {})
      Compiler.new(options).compile(mjml).to_h
    end

    alias to_html mjml2html
  end
end
