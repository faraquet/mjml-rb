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

This directory contains a Ruby-first implementation of the main MJML user-facing tooling:

- library API compatible with `mjml2html`
- command-line interface (`mjml`)
- migration and validation commands
- pure Ruby parser + AST + renderer (no external native renderer dependency)

## Quick start

```bash
bundle install
bundle exec ruby -Ilib -e 'require "mjml-rb"; puts MjmlRb.mjml2html("<mjml><mj-body><mj-section><mj-column><mj-text>Hello</mj-text></mj-column></mj-section></mj-body></mjml>")[:html]'
```

## CLI usage

```bash
bundle exec bin/mjml example.mjml -o output.html
bundle exec bin/mjml --validate example.mjml
bundle exec bin/mjml --migrate old.mjml -s
```

## Implementation idea

> **Zero-dependency pure-Ruby MJML renderer.**
>
> The npm `mjml` package requires Node.js at build time (or runtime via a child
> process / FFI bridge). This project replaces that entire pipeline with a single
> Ruby library: XML parsing, AST construction, attribute resolution, validation,
> and HTML rendering — all in Ruby, with no native extensions and no Node.js
> dependency. Drop it into a Rails, Sinatra, or plain Ruby project and render
> MJML templates the same way you render ERB — no extra runtime, no
> `package.json`, no `node_modules`.

Remaining parity work is tracked in [npm ↔ Ruby Parity Audit](/docs/PARITY_AUDIT.md).
