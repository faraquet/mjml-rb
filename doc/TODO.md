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
- [ ] Fix button/table fallback attribute mismatches against npm. Recent log comparison showed cases where Ruby emitted `bgcolor="#414141"` while the effective button background was white, which is risky for Outlook-style fallback rendering.
- [ ] Replace or further constrain the `Nokogiri` post-processing path used by `mj-html-attributes` and inline style injection. It works for the current cases, but it is still a behavior fork from npm and already needed selector fallbacks such as `:lang(...)`.
- [ ] Rewrite `mj-html-attributes` so it does not depend on `Nokogiri` to parse rendered HTML and apply CSS-selector-based attribute injections, if we want to keep the runtime dependency surface minimal.

## P2: Component audit follow-ups

- [ ] Compare `lib/mjml-rb/components/section.rb` against `upstream/packages/mjml-section/src/index.js` and `upstream/packages/mjml-wrapper/src/index.js` for remaining wrapper-only behavior, especially around Outlook wrappers and `gap`.
- [ ] Compare `lib/mjml-rb/components/column.rb` against `upstream/packages/mjml-column/src/index.js` for the remaining width, gutter, and Outlook child wrapper edge cases after the already-ported border-radius work.
- [ ] Compare `lib/mjml-rb/components/social.rb` against `upstream/packages/mjml-social/src/Social.js` and `upstream/packages/mjml-social/src/SocialElement.js` for network defaults, layout modes, and full validator metadata.
- [ ] Compare `lib/mjml-rb/components/accordion.rb` against the four upstream accordion classes for any remaining title/text defaults and ending-tag behavior that is currently only covered by ad-hoc tests.

## P3: Upstream test backlog

The dedicated component-level tests currently cover:

- `accordion-fontFamily`
- `accordion-padding`
- `accordionTitle-fontWeight`
- `carousel-hoverSupported`
- `carousel-rendering`
- `carousel-validation`
- `column-border-radius`
- `html-attributes`
- `html-comments`
- `lazy-head-style`
- `navbar-ico-padding`
- `social-align`
- `social-icon-height`
- `table-cellspacing`
- `tableWidth`
- `wrapper-border-radius`
- `wrapper-gap`

## P4: Test structure cleanup

- [ ] Keep moving behavior-specific assertions out of `test/test_compiler.rb` into focused files that mirror upstream npm test names where possible.
- [ ] Add validator-specific tests whenever a component gains a new `ALLOWED_ATTRIBUTES` map, so render parity and validator parity stay coupled.

## P5: Attribute and rendering inconsistencies (npm 4.18.0 audit)

Detailed comparison of Ruby component attributes, defaults, and rendering logic against `upstream/packages/` (npm 4.18.0). Grouped by impact.

### Low impact — dependency rule divergences

- [ ] **`mj-raw` / `mj-table` / `mj-text` child validation.** npm declares these as ending-tag components with empty child arrays (`[]`). Ruby declares `[/^(?!mj-).+/]` allowing any non-`mj-` children. This is a design-level divergence: npm treats their content as raw text (no child validation), while Ruby structurally parses and validates children.
- [ ] **`mj-attributes` wildcard regex.** npm uses `/^.*^/` which is a broken regex (second `^` is a literal character, not an anchor — it would only match strings containing a literal `^`). Ruby uses `/.*/` which correctly matches everything. Ruby is more correct here, but worth noting the upstream bug.
