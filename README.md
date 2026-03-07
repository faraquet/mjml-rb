# MJML Ruby Implementation

> **⚠️ EXPERIMENTAL — USE AT YOUR OWN RISK**
>
> This is an **unofficial, experimental** Ruby port of the MJML email framework.
> It is **not affiliated with or endorsed by the MJML team**.
> The output HTML may differ from the reference `mjml` npm package in subtle ways,
> and not all components or attributes are fully implemented yet.
> **Do not use in production without thorough testing of every template against
> the official npm renderer.** API and output format may change without notice.
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

## Migration status

The table below tracks current JS-to-Ruby migration status for MJML components in this repo.

| Component | Status | Notes |
| --- | --- | --- |
| `mj-body` | migrated | Ruby component exists and matches the upstream `mj-body` behavior currently vendored in `lib/mjml-rb/components/mjml-body`. |
| `mj-section` | migrated | Implemented in `section.rb`. |
| `mj-wrapper` | migrated | Implemented via `section.rb`. |
| `mj-column` | migrated | Implemented in `column.rb`. |
| `mj-group` | migrated | Rendered directly by the renderer. |
| `mj-text` | migrated | Implemented in `text.rb`. |
| `mj-image` | migrated | Implemented in `image.rb`. |
| `mj-button` | migrated | Implemented in `button.rb`. |
| `mj-divider` | migrated | Implemented in `divider.rb`. |
| `mj-table` | migrated | Implemented in `table.rb`. |
| `mj-social` | migrated | Implemented in `social.rb`. |
| `mj-social-element` | migrated | Implemented in `social.rb`. |
| `mj-accordion` | migrated | Implemented in `accordion.rb`. |
| `mj-accordion-element` | migrated | Implemented in `accordion.rb`. |
| `mj-accordion-title` | migrated | Implemented in `accordion.rb`. |
| `mj-accordion-text` | migrated | Implemented in `accordion.rb`. |
| `mj-spacer` | migrated | Implemented in `spacer.rb`. |
| `mj-hero` | partial | Rendered directly by the renderer with simplified behavior. |
| `mj-navbar` | partial | Rendered directly by the renderer with simplified behavior. |
| `mj-navbar-link` | partial | Rendered directly by the renderer with simplified behavior. |
| `mj-raw` | partial | Supported as passthrough content, but not as a dedicated migrated component. |
| `mj-head` | partial | Core tags such as `mj-title`, `mj-preview`, `mj-style`, `mj-font`, and `mj-attributes` are supported. |
| `mj-attributes` | partial | `mj-all`, `mj-class`, and per-tag defaults are supported. |
| `mj-all` | partial | Supported through `mj-attributes`. |
| `mj-class` | partial | Supported through `mj-attributes`. |
| `mj-title` | partial | Supported through head context. |
| `mj-preview` | partial | Supported through head context. |
| `mj-style` | partial | Supported, including inline CSS application. |
| `mj-font` | partial | Supported for font link injection. |
| `mj-carousel` | not migrated | Declared in dependency rules but no renderer implementation yet. |
| `mj-carousel-image` | not migrated | Declared in dependency rules but no renderer implementation yet. |
| `mj-breakpoint` | not migrated | Allowed in `mj-head`, but not implemented. |
| `mj-html-attributes` | migrated | Supported in `mj-head` and applied to the rendered HTML via CSS selectors. |
| `mj-selector` | migrated | Supported as the selector container for `mj-html-attribute` rules. |
| `mj-html-attribute` | migrated | Supported for injecting custom HTML attributes into matched rendered nodes. |

Remaining top-level migration work is mainly `mj-carousel`, `mj-carousel-image`, and `mj-breakpoint`, plus bringing the remaining renderer-owned partial implementations closer to upstream JS behavior.

TODO: `mj-html-attributes` currently uses `Nokogiri` to parse rendered HTML and apply CSS-selector-based attribute injections. Rewrite this path to avoid `Nokogiri` if we want to keep the runtime dependency surface minimal.
