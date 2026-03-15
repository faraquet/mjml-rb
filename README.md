# MJML Ruby Implementation

> **⚠️ EXPERIMENTAL — USE AT YOUR OWN RISK**
>
> This is an **unofficial, experimental** Ruby port of the MJML email framework.
> It is **not affiliated with or endorsed by the MJML team**.
> The output HTML may differ from the reference `mjml` npm package in subtle ways,
> and not all components or attributes are fully implemented yet.
> **Do not use in production without thorough testing of every template against
> the official npm renderer.** API and output format may change without notice.
> This is a **fully open source project**, and help is welcome:
> feedback, bug reports, test cases, optimizations, proposals, and pull requests.
> No warranty of any kind is provided.

This gem provides a Ruby-first implementation of the main MJML tooling:

- library API compatible with `mjml2html`
- command-line interface (`mjml`)
- validation commands
- pure Ruby parser, AST, validator, and renderer
- no Node.js runtime and no shelling out to the official npm renderer

## Compatibility

This project targets **MJML v4 only**.

- parsing, validation, and rendering are implemented against the MJML v4 document structure
- component rules and attribute validation follow the MJML v4 model

## Quick start

```bash
bundle install
bundle exec ruby -Ilib -e 'require "mjml-rb"; puts MjmlRb.mjml2html("<mjml><mj-body><mj-section><mj-column><mj-text>Hello</mj-text></mj-column></mj-section></mj-body></mjml>")[:html]'
```

## CLI usage

```bash
bundle exec bin/mjml example.mjml -o output.html
bundle exec bin/mjml --validate example.mjml
```

## Rails integration

In a Rails app, requiring the gem registers an `ActionView` template handler for
`.mjml` templates through a `Railtie`.

By default, `.mjml` files are treated as raw MJML/XML source.

If you want Slim-backed MJML templates, configure it explicitly:

```ruby
config.mjml_rb.rails_template_language = :slim
```

Supported values are `:slim` and `:haml`.

With a configured `rails_template_language`, `.mjml` templates are rendered
through that template engine first, so partials and embedded Ruby can assemble
MJML before the outer template is compiled to HTML. Without that setting,
non-XML MJML source is rejected instead of being guessed.

For `:slim` or `:haml`, the matching Rails template handler must already be
registered in `ActionView` by the corresponding gem or integration layer.

Create a view such as `app/views/user_mailer/welcome.html.mjml`:

```mjml
<mjml>
  <mj-body>
    <mj-section>
      <mj-column>
        <mj-text>Hello from Rails</mj-text>
      </mj-column>
    </mj-section>
  </mj-body>
</mjml>
```

Then render it like any other Rails template:

```ruby
class UserMailer < ApplicationMailer
  def welcome
    mail(to: "user@example.com", subject: "Welcome")
  end
end
```

Rails rendering uses strict MJML validation by default. You can override the
compiler options in your application config:

```ruby
config.mjml_rb.compiler_options = { validation_level: "soft" }
```

## Custom components

You can register custom MJML components written in Ruby:

```ruby
class MjRating < MjmlRb::Components::Base
  TAGS = ["mj-rating"].freeze
  ALLOWED_ATTRIBUTES = { "stars" => "integer", "color" => "color" }.freeze
  DEFAULT_ATTRIBUTES = { "stars" => "5", "color" => "#f4b400" }.freeze

  def render(tag_name:, node:, context:, attrs:, parent:)
    stars = (attrs["stars"] || "5").to_i
    color = attrs["color"] || "#f4b400"
    %(<div style="color:#{escape_attr(color)}">#{"\u2605" * stars}</div>)
  end
end

MjmlRb.register_component(MjRating,
  dependencies: { "mj-column" => ["mj-rating"] },
  ending_tags: ["mj-rating"]
)
```

The `dependencies` hash declares which parent tags accept the new component as a child. The `ending_tags` list tells the parser to treat content as raw HTML (like `mj-text`). Both are optional.

Once registered, the component works in MJML markup and is validated like any built-in component.

## `.mjmlrc` config file

Place a `.mjmlrc` file (JSON) in your project root to auto-register custom components and set default compiler options:

```json
{
  "packages": [
    "./lib/mjml_components/mj_rating.rb"
  ],
  "options": {
    "beautify": true,
    "validation-level": "soft"
  }
}
```

- **`packages`** — Ruby files to `require`. Each file should call `MjmlRb.register_component` to register its components.
- **`options`** — Default compiler options. CLI flags and programmatic options override these.

The CLI loads `.mjmlrc` automatically from the working directory. For the library API, load it explicitly:

```ruby
MjmlRb::ConfigFile.load("/path/to/project")
result = MjmlRb.mjml2html(mjml_string)
```

## Architecture

The compile pipeline is intentionally simple and fully Ruby-based:

1. `MjmlRb.mjml2html` calls `MjmlRb::Compiler`.
2. `MjmlRb::Parser` normalizes the source, expands `mj-include`, and builds an `AstNode` tree.
3. `MjmlRb::Validator` checks structural rules and supported attributes.
4. `MjmlRb::Renderer` resolves head metadata, applies component defaults, and renders HTML.
5. `MjmlRb::Compiler` post-processes the output and returns a `Result`.

The key architectural idea is that the project uses a small shared AST plus a component registry:

- the parser produces generic `AstNode` objects instead of component-specific node types
- structure rules live in `lib/mjml-rb/dependencies.rb`
- rendering logic lives in `lib/mjml-rb/components/*`
- head components populate a shared rendering context
- body components consume that context and emit the final HTML

That split keeps the compiler pipeline predictable:

- parsing is responsible for source normalization and include expansion
- validation is responsible for MJML structure and attribute checks
- rendering is responsible for HTML generation and responsive email output

## Project structure

The main files are organized like this:

```text
lib/mjml-rb.rb                    # public gem entry point
lib/mjml-rb/compiler.rb           # orchestration: parse -> validate -> render
lib/mjml-rb/parser.rb             # MJML/XML normalization, includes, AST building
lib/mjml-rb/ast_node.rb           # shared tree representation
lib/mjml-rb/validator.rb          # structural and attribute validation
lib/mjml-rb/dependencies.rb       # allowed parent/child relationships
lib/mjml-rb/renderer.rb           # HTML document assembly and render context
lib/mjml-rb/components/*          # per-component rendering and head handling
lib/mjml-rb/result.rb             # result object returned by the compiler
lib/mjml-rb/cli.rb                # CLI implementation used by bin/mjml
docs/ARCHITECTURE.md              # deeper architecture notes
docs/PARITY_AUDIT.md              # npm vs Ruby parity tracking
```

If you want the full internal walkthrough, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Implementation goal

> **Ruby MJML pipeline without the Node.js renderer.**
>
> The npm `mjml` package requires Node.js at build time (or runtime via a child
> process / FFI bridge). This project replaces that entire pipeline with a single
> Ruby library: XML parsing, AST construction, attribute resolution, validation,
> and HTML rendering — all in Ruby, with no Node.js runtime and no need to
> shell out to the official MJML renderer. Drop it into a Rails, Sinatra, or
> plain Ruby project and render MJML templates the same way you render ERB — no
> extra runtime, no
> `package.json`, no `node_modules`.

Remaining parity work is tracked in [npm ↔ Ruby Parity Audit](docs/PARITY_AUDIT.md).
