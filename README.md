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

## Migration status

The table below tracks current JS-to-Ruby migration status for MJML components in this repo.

| Component | Status | Notes |
| --- | --- | --- |
| `mj-body` | migrated | Ruby component exists and matches the upstream `mj-body` behavior currently vendored in `lib/mjml-rb/components/mjml-body`. |
| `mj-section` | migrated | Implemented in `section.rb`. |
| `mj-wrapper` | migrated | Implemented via `section.rb`. |
| `mj-column` | migrated | Implemented in `column.rb`. |
| `mj-group` | migrated | Implemented in `group.rb`, including width-aware child rendering and Outlook table wrappers. |
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
| `mj-hero` | migrated | Implemented in `hero.rb` with fixed/fluid modes, inner content wrapper, and Outlook VML background fallback. |
| `mj-navbar` | migrated | Implemented in `navbar.rb`, including `base-url` propagation and breakpoint-aware hamburger CSS. |
| `mj-navbar-link` | migrated | Implemented in `navbar.rb` as an ending-tag navbar child component. |
| `mj-raw` | migrated | Implemented in `raw.rb`, including head insertion and top-level `position="file-start"` output before the doctype. |
| `mj-head` | migrated | Implemented in `head.rb` and dispatches supported head children through component handlers. |
| `mj-attributes` | migrated | Implemented in `attributes.rb`, including npm-style `mj-class` descendant defaults. |
| `mj-all` | migrated | Implemented through `attributes.rb` with npm-style global default attribute precedence. |
| `mj-class` | migrated | Supported through `attributes.rb`, including nested per-tag descendant defaults. |
| `mj-title` | migrated | Implemented in `head.rb`. |
| `mj-preview` | migrated | Implemented in `head.rb`. |
| `mj-style` | migrated | Implemented in `head.rb`, including inline-style registration. |
| `mj-font` | migrated | Implemented in `head.rb`. |
| `mj-carousel` | migrated | Implemented in `carousel.rb`, including per-instance radio/thumbnail CSS, Outlook fallback rendering, and thumbnail/control output. |
| `mj-carousel-image` | migrated | Implemented in `carousel_image.rb`, including radio, thumbnail, and main image rendering helpers used by `mj-carousel`. |
| `mj-breakpoint` | migrated | Supported in `mj-head` and used to control desktop column media-query widths. |
| `mj-html-attributes` | migrated | Supported in `mj-head` and applied to the rendered HTML via CSS selectors. |
| `mj-selector` | migrated | Supported as the selector container for `mj-html-attribute` rules. |
| `mj-html-attribute` | migrated | Supported for injecting custom HTML attributes into matched rendered nodes. |

A more detailed parity backlog lives in [doc/TODO.md](/doc/TODO.md).
