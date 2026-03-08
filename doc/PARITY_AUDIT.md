# Inconsistencies: Ruby (mjml-rb v0.2.15) vs NPM (MJML v4.18.0)

Detailed comparison of attributes, defaults, rendering logic, and dependency rules. NPM source located in `.mjml-src/packages/`.

---

## 1. `mj-section` — Major Gaps

### Missing attributes (Ruby has none of these)

| Attribute | NPM Type | NPM Default |
|---|---|---|
| ~~`background-url`~~ | ~~string~~ | ~~—~~ |
| ~~`background-repeat`~~ | ~~enum(repeat,no-repeat)~~ | ~~`'repeat'`~~ |
| ~~`background-size`~~ | ~~string~~ | ~~`'auto'`~~ |
| ~~`background-position`~~ | ~~string~~ | ~~`'top center'`~~ |
| ~~`background-position-x`~~ | ~~string~~ | ~~—~~ |
| ~~`background-position-y`~~ | ~~string~~ | ~~—~~ |
| `full-width` | enum(full-width,false,) | — |
| `text-padding` | unit(px,%){1,4} | `'4px 4px 4px 0'` |

> Background image attributes (`background-url`, `background-repeat`, `background-size`, `background-position`, `background-position-x/y`) and VML rendering were implemented. The remaining gaps are `full-width` mode and `text-padding`.

### Missing rendering behavior

- ~~NPM renders VML `<v:rect>/<v:fill>` for Outlook background images — Ruby had no background image support at all~~ (fixed)
- ~~NPM wraps content in an extra `<div style="line-height:0;font-size:0">` when `background-url` is set~~ (fixed)
- NPM has two render paths: `renderSimple()` and `renderFullWidth()` — Ruby only has `renderSimple`-equivalent
- NPM adds `border-collapse: separate` and `overflow: hidden` on the div when `border-radius` is set — Ruby doesn't
- NPM applies `margin-top` from context `gap` on non-first sections — Ruby doesn't
- NPM includes `border-radius` in the div style — Ruby doesn't

## 2. `mj-wrapper` — Missing Features

| Gap | Detail |
|---|---|
| `background-*` rendering | Wrapper now inherits background-* attributes via `SECTION_ALLOWED_ATTRIBUTES`, but `render_wrapper` does not apply background styles, VML, or innerDiv |
| `text-padding` | Inherited from section in NPM, absent in Ruby |

Ruby wrapper has `full-width` which is correct. NPM wrapper also has `full-width` via inheritance.

## 3. `mj-text` — Remaining Validation Gaps

- NPM `align` allows `justify` — Ruby now matches this in validation metadata
- Ruby now supports `background-color` and has an `ALLOWED_ATTRIBUTES` map
- Any remaining `mj-text` parity work is mostly around ending-tag semantics, not the basic attribute contract

## 4. Dependency Rules Differences

| Tag | NPM | Ruby | Issue |
|---|---|---|---|
| `mj-raw` | `[]` (ending tag, no children) | `[/^(?!mj-).+/]` | Ruby allows non-mj children; NPM treats as raw text |
| `mj-table` | `[]` (ending tag) | `[/^(?!mj-).+/]` | Same divergence |
| `mj-text` | `[]` (ending tag) | `[/^(?!mj-).+/]` | Same divergence |
| `mj-attributes` | `[/^.*^/]` | `[/.*/]` | NPM regex is broken (literal `^`). Ruby is more correct |

NPM uses "ending tag" semantics (raw content, no child validation), while Ruby structurally parses children. Not wrong, but differs from upstream.

## 5. `mj-social` — Missing `table-layout`

NPM has `table-layout: 'enum(auto,fixed)'`. Ruby doesn't have it.

## 6. `mj-image` — Extra `full-width` Attribute

Ruby's `mj-image` supports a `full-width` attribute that NPM's `mj-image` does **not** have. May be an accidental addition.

## 7. `mj-section` — `border-radius` Type Mismatch

- NPM: `border-radius: 'string'` (accepts any CSS value including elliptical like `50%/10%`)
- Ruby: `border-radius: 'unit(px,%){1,4}'` (stricter — rejects valid CSS border-radius values)

## 8. Skeleton / Document-Level Gaps

Already tracked in TODO P1:
- Missing `xmlns` attributes on `<html>`
- Missing `X-UA-Compatible` meta block
- Missing Outlook `OfficeDocumentSettings`
- Missing `mso-line-height-rule` / `.mj-outlook-group-fix` styles
- Missing `word-spacing:normal` on `<body>`
- Separate CSS style bucket ordering differs

## 9. `mj-section` — Outlook `<table>` Style

- NPM: renders `style` with `width` and optionally `padding-top` (for gap support) on the outlook wrapper table
- Ruby: renders `style` as `"width:#{container_px}px;"` — no gap padding-top

---

## Summary by Priority

### High impact (feature gaps users will hit)

1. ~~`mj-section` background image support (background-url + VML) — completely missing~~ (fixed)
2. `mj-section` full-width mode — missing
3. `mj-wrapper` background rendering and `text-padding` — missing
4. `mj-section` missing `text-padding`

### Medium impact (validation/correctness)

5. `mj-section` border-radius overflow/border-collapse handling
6. `mj-social` missing `table-layout`
7. `mj-section` border-radius type too strict
8. `mj-image` extra `full-width` not in upstream

### Low impact (already tracked or minor)

10. Dependency rule differences for ending-tag components
11. Missing ALLOWED_ATTRIBUTES constants (TODO P0)
12. Skeleton markup differences (TODO P1)
