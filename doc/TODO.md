# Port TODO

This checklist is based on a direct comparison between the current Ruby code in `lib/mjml-rb` and the upstream npm implementation. Source paths under `upstream/` refer to a local reference mirror when present.

Even when a template looks visually the same in email clients, the generated HTML and CSS can still differ noticeably from the npm renderer. The main remaining sources of output differences are:

- skeleton markup: the outer HTML document still differs from npm in some head and Outlook-specific scaffolding
- style bucket ordering: npm keeps several CSS buckets separate, while the Ruby renderer still flattens parts of head CSS differently
- post-processing behavior: the Ruby renderer still relies on `Nokogiri`-based HTML post-processing for some features such as `mj-html-attributes` and inline style application

So output size, CSS ordering, and exact markup can still differ even when the rendered email appears functionally equivalent.

## P0: Remaining npm parity blockers

- [ ] Add `ALLOWED_ATTRIBUTES` and validator type coverage for components that currently render without npm-style validation metadata: `lib/mjml-rb/components/accordion.rb`, `lib/mjml-rb/components/button.rb`, `lib/mjml-rb/components/divider.rb`, `lib/mjml-rb/components/image.rb`, `lib/mjml-rb/components/social.rb`, `lib/mjml-rb/components/table.rb`, and `lib/mjml-rb/components/text.rb`.

## P1: Core runtime parity gaps

- [ ] Bring `lib/mjml-rb/parser.rb` in line with `upstream/packages/mjml-parser-xml/src/index.js` for `mj-include` handling:
  - support `type="css"`
  - support `css-inline="inline"`
  - track circular includes
  - preserve file and line metadata
  - collect include errors instead of failing immediately
- [ ] Rework ending-tag parsing to match npm semantics. The npm parser preserves raw `content` for ending-tag components such as `mj-text`, `mj-button`, `mj-table`, `mj-raw`, `mj-style`, and `mj-preview`; the current REXML path parses nested markup structurally, which can diverge for HTML-ish or template-heavy content.
- [ ] Extend `lib/mjml-rb/validator.rb` to support the npm core type set from `upstream/packages/mjml-core/src/types`: `boolean` and `integer` are still missing.
- [ ] Align the generated HTML skeleton in `lib/mjml-rb/renderer.rb` with `upstream/packages/mjml-core/src/helpers/skeleton.js`:
  - add `xmlns` attributes on `<html>`
  - add the `X-UA-Compatible` meta block
  - add Outlook `OfficeDocumentSettings`
  - add the `lte mso 11` `.mj-outlook-group-fix` style block
  - restore `word-spacing:normal` on `<body>`
  - keep separate head style buckets like npm instead of flattening everything into one style tag
- [ ] Further align inline `mj-style inline="inline"` processing in `lib/mjml-rb/renderer.rb`. Bucket routing now matches npm more closely, but the current CSS parser still strips `@` rules and applies a simplified declaration merge instead of npm's richer cascade-aware inlining path.
- [ ] Fix button/table fallback attribute mismatches against npm. Recent log comparison showed cases where Ruby emitted `bgcolor="#414141"` while the effective button background was white, which is risky for Outlook-style fallback rendering.
- [ ] Replace or further constrain the `Nokogiri` post-processing path used by `mj-html-attributes` and inline style injection. It works for the current cases, but it is still a behavior fork from npm and already needed selector fallbacks such as `:lang(...)`.
- [ ] Rewrite `mj-html-attributes` so it does not depend on `Nokogiri` to parse rendered HTML and apply CSS-selector-based attribute injections, if we want to keep the runtime dependency surface minimal.

## P2: Component audit follow-ups

- [ ] Compare `lib/mjml-rb/components/section.rb` against `upstream/packages/mjml-section/src/index.js` and `upstream/packages/mjml-wrapper/src/index.js` for remaining wrapper-only behavior, especially around Outlook wrappers, background handling, and `gap`.
- [ ] Compare `lib/mjml-rb/components/column.rb` against `upstream/packages/mjml-column/src/index.js` for the remaining width, gutter, and Outlook child wrapper edge cases after the already-ported border-radius work.
- [ ] Compare `lib/mjml-rb/components/social.rb` against `upstream/packages/mjml-social/src/Social.js` and `upstream/packages/mjml-social/src/SocialElement.js` for network defaults, layout modes, and full validator metadata.
- [ ] Compare `lib/mjml-rb/components/accordion.rb` against the four upstream accordion classes for any remaining title/text defaults and ending-tag behavior that is currently only covered by ad-hoc tests.

## P3: Upstream test backlog

The dedicated component-level tests currently cover:

- `column-border-radius`
- `carousel-rendering`
- `carousel-validation`
- `html-attributes`
- `navbar-ico-padding`

Still worth porting from `upstream/packages/mjml/test`:

- [ ] `accordion-fontFamily`
- [ ] `accordion-padding`
- [ ] `accordionTitle-fontWeight`
- [ ] `html-comments`
- [ ] `lazy-head-style`
- [ ] `social-align`
- [ ] `social-icon-height`
- [ ] `table-cellspacing`
- [ ] `tableWidth`
- [ ] `wrapper-border-radius`
- [ ] `wrapper-gap`
- [ ] `carousel-hoverSupported`

## P4: Test structure cleanup

- [ ] Keep moving behavior-specific assertions out of `test/test_compiler.rb` into focused files that mirror upstream npm test names where possible.
- [ ] Add validator-specific tests whenever a component gains a new `ALLOWED_ATTRIBUTES` map, so render parity and validator parity stay coupled.
