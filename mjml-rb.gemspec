require_relative "lib/mjml_rb/version"

Gem::Specification.new do |spec|
  spec.name = "mjml-rb"
  spec.version = MjmlRb::VERSION
  spec.authors = ["Andrei Andriichuk"]
  spec.email = ["andreiandriichuk@gmail.com"]

  spec.summary = "Ruby implementation of the MJML toolchain"
  spec.description = "Ruby-first MJML compiler API and CLI with compatibility-focused behavior."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.files = Dir.chdir(__dir__) do
    Dir.glob("{bin,lib,test}/**/*") + ["Gemfile", "mjml-rb.gemspec", "README.md"]
  end
  spec.bindir = "bin"
  spec.executables = ["mjml"]
  spec.require_paths = ["lib"]
  spec.add_dependency "rexml"
end
