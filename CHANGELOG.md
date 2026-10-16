# Changelog

## 0.6.0

Target MJML 5.4.1 with a development-only pinned reference compiler. Runtime
compilation remains pure Ruby and synchronous.

- Support `css_parser` 3.x alongside 1.x and 2.x, with all three dependency
  lines in the Ruby 3.3, 3.4 and 4.0 CI matrix.
- Disable includes by default; add canonical root allowlists and structured
  include diagnostics. Track recursive dependencies in watch mode.
- Move body id/class and preview ownership to `mj-body`; add responsive section
  gutters, social icon borders, string radii and v5 hero/accordion behavior.
- Preserve Outlook conditionals and raw/template whitespace during formatting;
  add CSS template validation and configurable CSS compaction.
- Accept upstream option aliases, opt-in `.mjmlconfig` options, and explicit
  unsupported-option errors. Make CLI validation silent and render-free.
- Fix default column widths, raw siblings, social ending content, image width,
  CSS include order and shared component registration metadata.

See [the migration guide](docs/MIGRATING_TO_V5.md) for breaking changes and
[the compatibility audit](docs/PARITY_AUDIT.md) for remaining differences.
