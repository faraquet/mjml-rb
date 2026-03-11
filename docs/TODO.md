# Port TODO

This checklist is based on a direct comparison between the current Ruby code in `lib/mjml-rb` and the upstream npm implementation. Source paths under `upstream/` refer to a local reference mirror when present.

Even when a template looks visually the same in email clients, the generated HTML and CSS can still differ noticeably from the npm renderer. The main remaining sources of output differences are:

- skeleton markup: the outer HTML document still differs from npm in some head and Outlook-specific scaffolding
- post-processing behavior: the Ruby renderer still relies on `Nokogiri`-based HTML post-processing for some features such as `mj-html-attributes` and inline style application

So output size, CSS ordering, and exact markup can still differ even when the rendered email appears functionally equivalent.

## P1: Core runtime parity gaps

- [x] Bring `lib/mjml-rb/parser.rb` in line with `upstream/packages/mjml-parser-xml/src/index.js` for `mj-include` handling:
  - [x] support `type="css"`
  - [x] support `css-inline="inline"`
  - [x] track circular includes
  - [ ] preserve file and line metadata
  - [x] collect include errors instead of failing immediately
- [x] Rework ending-tag parsing to match npm semantics. The parser now wraps inner content of ending-tag components (`mj-text`, `mj-button`, `mj-accordion-text`, `mj-accordion-title`, `mj-navbar-link`, `mj-raw`) in CDATA before REXML parsing, preserving raw HTML as `node.content` on the AST. Components use the preserved content directly. `mj-table` is excluded because its component needs structural access for attribute normalization.
- [x] Further align inline `mj-style inline="inline"` processing in `lib/mjml-rb/renderer.rb`. The CSS inliner now preserves `@`-rules (`@media`, `@font-face`, etc.) by extracting them and injecting them as a `<style>` block instead of stripping them. Rules are sorted by CSS specificity before application, so higher-specificity selectors correctly override lower ones regardless of source order.
- [ ] Replace or further constrain the `Nokogiri` post-processing path used by `mj-html-attributes` and inline style injection. It works for the current cases, but it is still a behavior fork from npm and already needed selector fallbacks such as `:lang(...)`.
- [ ] Rewrite `mj-html-attributes` so it does not depend on `Nokogiri` to parse rendered HTML and apply CSS-selector-based attribute injections, if we want to keep the runtime dependency surface minimal.


