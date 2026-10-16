[![Gem Version](https://badge.fury.io/rb/mjml-rb.svg)](https://badge.fury.io/rb/mjml-rb)

# MJML Ruby Implementation

`mjml-rb` **0.6.0** is a pure-Ruby compiler targeting **MJML 5.4.1**.
The gem version and the upstream MJML version are separate. Node.js/npm is used
only for the development reference checks; compilation requires neither.

- Synchronous `mjml2html` library API returning HTML, errors and warnings
- Command-line interface (`mjml`)
- Rails integration (ActionView template handler for `.mjml` views)
- Validation (soft, strict, skip)
- Custom component support
- Pure Ruby parser, AST, validator, and renderer
- CSS inlining tested with `css_parser` 1.21, 2.x and 3.x

**[Full Usage Guide](docs/USAGE.md)** — API reference, all compiler options, component attribute tables, CLI flags, Rails setup, custom components, and more.

See the [0.6.0 release notes](docs/releases/v0.6.0.md) and [changelog](CHANGELOG.md).

## Installation

Requires Ruby **>= 3.3**, `css_parser` **>= 1.17, < 4**, and Nokogiri **>= 1.13**.
CI covers Ruby 3.3, 3.4 and 4.0 with `css_parser` 1.21, 2.x and 3.x.

```ruby
# Gemfile
gem "mjml-rb", "~> 0.6.0"
```

## Quick Start

```ruby
require "mjml-rb"

result = MjmlRb.mjml2html(<<~MJML)
  <mjml>
    <mj-body>
      <mj-section>
        <mj-column>
          <mj-text>Hello World!</mj-text>
        </mj-column>
      </mj-section>
    </mj-body>
  </mjml>
MJML

puts result[:html]     # compiled HTML
puts result[:errors]   # validation errors (if any)
puts result[:warnings] # non-blocking issues in soft validation
```

## CLI

```bash
mjml email.mjml -o email.html          # compile to file
mjml -r "templates/*.mjml" -o output/  # batch compile
mjml -v email.mjml                     # validate only
mjml -i -s < email.mjml                # stdin → stdout
```

See the [Usage Guide — CLI section](docs/USAGE.md#cli) for all flags and config options.

## Upgrading from mjml-rb 0.5.x (MJML v4)

The 0.6.x line uses v5 defaults. `mj-include` is silently omitted by default.
Enable local includes explicitly and supply the template's directory:

```ruby
MjmlRb.mjml2html(source,
  ignore_includes: false,
  file_path: File.dirname(template_path),
  actual_path: template_path
)
```

For the CLI, use `mjml email.mjml --config.allowIncludes -o email.html`.
Includes stay within the template's canonical root and any explicit `include_path`
roots; absolute paths and escapes are denied.

`mj-body` now owns the HTML `<body>`, including its `id` and `css-class`.
Update CSS selectors that expected the class on the inner article. Background
painting below short emails can consequently change in browser previews.
`minify` takes precedence over `beautify`; raw whitespace and Outlook conditionals
are preserved, but formatted output can differ from earlier releases.

See [the migration guide](docs/MIGRATING_TO_V5.md) for the breaking changes and
[the compatibility audit](docs/PARITY_AUDIT.md) for verified scope and limitations.

## Rails

Add the gem to your Gemfile — that's it. The `.mjml` template handler is registered automatically.

```xml
<!-- app/views/user_mailer/welcome.html.mjml -->
<mjml>
  <mj-body>
    <mj-section>
      <mj-column>
        <mj-text>Welcome to our service!</mj-text>
      </mj-column>
    </mj-section>
  </mj-body>
</mjml>
```

```ruby
class UserMailer < ApplicationMailer
  def welcome(user)
    mail(to: user.email, subject: "Welcome")
  end
end
```

Raw XML `.mjml` templates are compiled as supplied; embedded ERB is not evaluated.
For dynamic templates, load a Slim or Haml ActionView handler and set
`config.mjml_rb.rails_template_language = :slim` (or `:haml`). See the
[Usage Guide — Rails section](docs/USAGE.md#rails-integration) for examples.

## Architecture

```
MJML string → Parser → AST → Validator → Renderer → Formatter → HTML
```

1. **Parser** — normalizes source, expands explicitly enabled `mj-include`, produces a Nokogiri XML node tree
2. **Validator** — checks structure, hierarchy, and attribute types
3. **Renderer** — resolves head metadata, applies defaults, emits responsive HTML
4. **Formatter** — applies the selected formatting and CSS template checks

For the full internal walkthrough, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

The [compatibility audit](docs/PARITY_AUDIT.md) records pinned upstream checks and
maintainer-reported downstream Chrome comparisons. These are representative
browser renders, not certification across email clients. Customer screenshots
remain private; public examples use synthetic content.

## Contributing

This is a fully open source project — feedback, bug reports, test cases, and pull requests are welcome! Feel free to use it in your projects and let me know how it goes.

## Disclaimer

This is an unofficial Ruby port of the MJML email framework, not affiliated with or endorsed by the MJML team. Compatibility is checked against the pinned `mjml@5.4.1` compiler. This port remains experimental: the parser, CSS inliner and formatter have documented differences, and identical rendering across all email clients is not guaranteed.

## License

See [LICENSE](LICENSE) and [third-party notices](THIRD_PARTY_LICENSES.md).
