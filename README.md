# MJML Ruby Implementation

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
bundle exec bin/mjml doc/sample.mjml -o sample.html
```
