# Inconsistencies: Ruby (mjml-rb) vs NPM (MJML v4.18.0)

Detailed comparison of attributes, defaults, rendering logic, and dependency rules. NPM source located in `.mjml-src/packages/`.

---

## 1. Dependency Rules Differences

| Tag | NPM | Ruby | Issue |
|---|---|---|---|
| `mj-raw` | `[]` (ending tag, no children) | `[/^(?!mj-).+/]` | Ruby allows non-mj children; NPM treats as raw text |
| `mj-table` | `[]` (ending tag) | `[/^(?!mj-).+/]` | Same divergence |
| `mj-text` | `[]` (ending tag) | `[/^(?!mj-).+/]` | Same divergence |
| `mj-attributes` | `[/^.*^/]` | `[/.*/]` | NPM regex is broken (literal `^`). Ruby is more correct |

NPM uses "ending tag" semantics (raw content, no child validation), while Ruby structurally parses children. Not wrong, but differs from upstream.

## 2. Remaining Skeleton Gap

- Head CSS is still flattened into a single `<style>` tag. NPM keeps several CSS buckets separate. Already tracked in TODO P1.
