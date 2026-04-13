[![Gem Version](https://badge.fury.io/rb/mjml-rb.svg)](https://badge.fury.io/rb/mjml-rb)

# MJML Ruby Implementation

A pure-Ruby MJML v4 compiler — no Node.js required.

- Library API compatible with `mjml2html`
- Command-line interface (`mjml`)
- Rails integration (ActionView template handler for `.mjml` views)
- Validation (soft, strict, skip)
- Custom component support
- Pure Ruby parser, AST, validator, and renderer
- CSS inlining tested with `css_parser` 1.21 and 2.x

**[Full Usage Guide](docs/USAGE.md)** — API reference, all compiler options, component attribute tables, CLI flags, Rails setup, custom components, and more.

## Installation

`mjml-rb` requires Ruby 3.3 or newer.

```ruby
# Gemfile
gem "mjml-rb"
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
```

## CLI

```bash
mjml email.mjml -o email.html          # compile to file
mjml -r "templates/*.mjml" -o output/  # batch compile
mjml -v email.mjml                     # validate only
mjml -i -s < email.mjml                # stdin → stdout
```

See the [Usage Guide — CLI section](docs/USAGE.md#cli) for all flags and config options.

## Rails

Add the gem to your Gemfile — that's it. The `.mjml` template handler is registered automatically.

```erb
<!-- app/views/user_mailer/welcome.html.mjml -->
<mjml>
  <mj-body>
    <mj-section>
      <mj-column>
        <mj-text>Welcome, <%= @user.name %>!</mj-text>
      </mj-column>
    </mj-section>
  </mj-body>
</mjml>
```

```ruby
class UserMailer < ApplicationMailer
  def welcome(user)
    @user = user
    mail(to: user.email, subject: "Welcome")
  end
end
```

Supports Slim and Haml via `config.mjml_rb.rails_template_language = :slim`. See the [Usage Guide — Rails section](docs/USAGE.md#rails-integration) for full configuration.

## Architecture

```
MJML string → Parser → AST → Validator → Renderer → HTML
```

1. **Parser** — normalizes source, expands `mj-include`, produces a Nokogiri XML node tree
2. **Validator** — checks structure, hierarchy, and attribute types
3. **Renderer** — resolves head metadata, applies defaults, emits responsive HTML

For the full internal walkthrough, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

Remaining parity work is tracked in [npm ↔ Ruby Parity Audit](docs/PARITY_AUDIT.md).

## Contributing

This is a fully open source project — feedback, bug reports, test cases, and pull requests are welcome! Feel free to use it in your projects and let me know how it goes.

## Disclaimer

This is an unofficial Ruby port of the MJML email framework, not affiliated with or endorsed by the MJML team. All 22 MJML v4 components are implemented and tested against npm MJML v4.18.0. Output may differ from the npm renderer in cosmetic ways (whitespace, attribute ordering) but renders identically across email clients.

## License

MIT
