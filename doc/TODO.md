# Port TODO

This checklist is based on a direct comparison between the current Ruby code in `lib/mjml-rb` and the upstream npm implementation. Source paths under `upstream/` refer to a local reference mirror when present.

Even when a template looks visually the same in email clients, the generated HTML and CSS can still differ noticeably from the npm renderer. The main remaining sources of output differences are:

- skeleton markup: the outer HTML document still differs from npm in some head and Outlook-specific scaffolding
- post-processing behavior: the Ruby renderer still relies on `Nokogiri`-based HTML post-processing for some features such as `mj-html-attributes` and inline style application

So output size, CSS ordering, and exact markup can still differ even when the rendered email appears functionally equivalent.

## P1: Core runtime parity gaps

- [ ] Bring `lib/mjml-rb/parser.rb` in line with `upstream/packages/mjml-parser-xml/src/index.js` for `mj-include` handling:
  - support `type="css"`
  - support `css-inline="inline"`
  - track circular includes
  - preserve file and line metadata
  - collect include errors instead of failing immediately
- [ ] Rework ending-tag parsing to match npm semantics. The npm parser preserves raw `content` for ending-tag components such as `mj-text`, `mj-button`, `mj-table`, `mj-raw`, `mj-style`, and `mj-preview`; the current REXML path parses nested markup structurally, which can diverge for HTML-ish or template-heavy content.
- [ ] Further align inline `mj-style inline="inline"` processing in `lib/mjml-rb/renderer.rb`. Bucket routing now matches npm more closely, but the current CSS parser still strips `@` rules and applies a simplified declaration merge instead of npm's richer cascade-aware inlining path.
- [ ] Replace or further constrain the `Nokogiri` post-processing path used by `mj-html-attributes` and inline style injection. It works for the current cases, but it is still a behavior fork from npm and already needed selector fallbacks such as `:lang(...)`.
- [ ] Rewrite `mj-html-attributes` so it does not depend on `Nokogiri` to parse rendered HTML and apply CSS-selector-based attribute injections, if we want to keep the runtime dependency surface minimal.

## P2: Component audit follow-ups

- [ ] Compare `lib/mjml-rb/components/section.rb` against `upstream/packages/mjml-section/src/index.js` and `upstream/packages/mjml-wrapper/src/index.js` for remaining wrapper-only behavior, especially around Outlook wrappers and `gap`.

