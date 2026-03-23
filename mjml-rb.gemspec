require_relative "lib/mjml-rb/version"

Gem::Specification.new do |spec|
  spec.name = "mjml-rb"
  spec.version = MjmlRb::VERSION
  spec.authors = ["Andrei Andriichuk"]
  spec.email = ["andreiandriichuk@gmail.com"]

  spec.summary = "Ruby implementation of the MJML toolchain"
  spec.description = "Ruby-first MJML compiler API and CLI with compatibility-focused behavior."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.homepage = "https://github.com/faraquet/mjml-rb"
  spec.files = Dir.chdir(__dir__) do
    Dir.glob("{bin,lib}/**/*") + ["Gemfile", "LICENSE", "Rakefile", "mjml-rb.gemspec", "README.md"]
  end
  spec.bindir = "bin"
  spec.executables = ["mjml"]
  spec.require_paths = ["lib"]
  spec.add_dependency "css_parser", ">= 1.17"
  spec.add_dependency "nokogiri", ">= 1.13"
  spec.add_dependency "rexml", ">= 3.2.5"
end
