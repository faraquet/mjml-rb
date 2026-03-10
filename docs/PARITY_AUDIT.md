# Inconsistencies: Ruby (mjml-rb) vs NPM (MJML v4.18.0)

Detailed comparison of attributes, defaults, rendering logic, and dependency rules. NPM source located in `.mjml-src/packages/`.

---

## 1. Dependency Rules Differences

| Tag | NPM | Ruby | Issue |
|---|---|---|---|
| `mj-attributes` | `[/^.*^/]` | `[/.*/]` | NPM regex is broken (literal `^`). Ruby is more correct |

All ending-tag dependency rules (`mj-raw`, `mj-table`, `mj-text`) are now aligned with NPM (`[]`). The validator skips child checks for ending-tag components via `Dependencies::ENDING_TAGS`.
