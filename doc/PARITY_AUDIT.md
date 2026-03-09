# Inconsistencies: Ruby (mjml-rb v0.2.15) vs NPM (MJML v4.18.0)

Detailed comparison of attributes, defaults, rendering logic, and dependency rules. NPM source located in `.mjml-src/packages/`.

---

## 1. `mj-text` — Remaining Validation Gaps

- NPM `align` allows `justify` — Ruby now matches this in validation metadata
- Ruby now supports `background-color` and has an `ALLOWED_ATTRIBUTES` map
- Any remaining `mj-text` parity work is mostly around ending-tag semantics, not the basic attribute contract

## 2. Dependency Rules Differences

| Tag | NPM | Ruby | Issue |
|---|---|---|---|
| `mj-raw` | `[]` (ending tag, no children) | `[/^(?!mj-).+/]` | Ruby allows non-mj children; NPM treats as raw text |
| `mj-table` | `[]` (ending tag) | `[/^(?!mj-).+/]` | Same divergence |
| `mj-text` | `[]` (ending tag) | `[/^(?!mj-).+/]` | Same divergence |
| `mj-attributes` | `[/^.*^/]` | `[/.*/]` | NPM regex is broken (literal `^`). Ruby is more correct |

NPM uses "ending tag" semantics (raw content, no child validation), while Ruby structurally parses children. Not wrong, but differs from upstream.

## 3. `mj-image` — Extra `full-width` Attribute

Ruby's `mj-image` supports a `full-width` attribute that NPM's `mj-image` does **not** have. May be an accidental addition.

## 4. Skeleton / Document-Level Gaps

Already tracked in TODO P1:
- Missing `xmlns` attributes on `<html>`
- Missing `X-UA-Compatible` meta block
- Missing Outlook `OfficeDocumentSettings`
- Missing `mso-line-height-rule` / `.mj-outlook-group-fix` styles
- Missing `word-spacing:normal` on `<body>`
- Separate CSS style bucket ordering differs

---

## Summary by Priority

### Medium impact (validation/correctness)

1. `mj-image` extra `full-width` not in upstream

### Low impact (already tracked or minor)

10. Dependency rule differences for ending-tag components
11. Skeleton markup differences (TODO P1)
