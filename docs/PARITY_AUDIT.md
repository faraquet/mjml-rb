# npm ↔ Ruby Parity Audit

Comparison of upstream npm MJML v4.18.0 against the Ruby port.
Last updated 2026-03-15.

---

## Legend

- **Match** — behavior is functionally equivalent
- **Partial** — core logic is ported but details diverge
- **Missing** — feature exists in npm but not in Ruby

---

## 1. Core Rendering Pipeline

| Feature | npm (`mjml-core/src/index.js`) | Ruby (`renderer.rb`, `compiler.rb`) | Status |
|---|---|---|---|
| Parse → validate → render flow | `MJMLParser` → `MJMLValidator` → `processing(mjBody)` | `Parser#parse` → `Validator#validate` → `Renderer#render` | Match |
| Validation levels (skip/soft/strict) | All three; strict throws `ValidationError` | All three; strict returns early with errors | Match |
| CSS inlining (`mj-style inline`) | Uses **Juice** library with `juiceOptions`, `juicePreserveTags` | Custom Nokogiri-based inliner with specificity sort; Juice attribute syncing replicated (`widthElements`, `heightElements`, `styleToAttribute`, `tableElements`) | Partial |
| `mj-html-attributes` application | **Cheerio** (`xmlMode: true, decodeEntities: false`), applied **before** skeleton on body content | **Nokogiri** (`Nokogiri::HTML::DocumentFragment`), applied **before** skeleton on body content | Partial |
| Pipeline ordering | minify conditionals → html-attributes → skeleton → Juice → merge conditionals | minify conditionals → html-attributes → skeleton → inline CSS → merge conditionals → prepend before_doctype | Match |
| Outlook conditional minification | `minifyOutlookConditionnals()` strips whitespace between tags inside `<!--[if …]>` blocks *before* skeleton | Applied to body content before skeleton generation | Match |
| Outlook conditional merging | `mergeOutlookConditionnals()` merges adjacent `<!--[endif]--><!--[if mso\|IE]>` *after* CSS inlining | Applied globally after CSS inlining | Match |
| Background-color on `<body>` | Skeleton adds `background-color:${backgroundColor}` to `<body style>` | Propagated from `context[:background_color]` to `<body style>` | Match |
| `beautify` / `minify` post-processing | `js-beautify` / `html-minifier` (deprecated, warns) | Regex-based simplistic implementation | Partial |
| `forceOWADesktop` option | Adds `[owa]` prefixed media queries when `owa="desktop"` on `<mjml>` | Supported via conditional OWA media queries | Match |
| `printerSupport` option | Adds `@media only print` media queries | Supported via `printer_support` render option | Match |
| `htmlAttributes` nil-only filtering | `omitBy(attributes, isNil)` — keeps empty strings | `html_attrs` skips only `nil` — keeps empty strings | Match |
| `juiceOptions` / `juicePreserveTags` | Pass-through to Juice | N/A (custom CSS inliner) | Missing |
| `.mjmlrc` config file support | `handleMjmlConfig` reads `.mjmlrc` for packages, options, preprocessors | `ConfigFile.load` reads `.mjmlrc` for packages and options; CLI loads automatically | Match |
| Custom component registration | `registerComponent()`, presets with `assignComponents` | `MjmlRb.register_component(klass, dependencies:, ending_tags:)` | Match |

### Skeleton Markup Differences

The HTML document scaffold (`skeleton.js` vs `build_html_document`) is very close. Known divergences:

| Detail | npm | Ruby | Priority |
|---|---|---|---|
| `<meta charset="utf-8">` | Not present | Not present | Match |
| `<body style>` includes background-color | Yes (`word-spacing:normal;background-color:…;`) | Yes (`word-spacing:normal;background-color:…`) | Match |
| Style tag construction | `headStyle` is a hash of *functions* called with `breakpoint` | `component_head_styles` are pre-computed strings | Match (same output) |
| OWA desktop queries | Conditional output when `forceOWADesktop` | Conditional output when `owa="desktop"` | Match |
| Print media queries | Conditional output when `printerSupport` | Conditional output when `printer_support` is enabled | Match |

---

## 2. Parser

| Feature | npm (`mjml-parser-xml/src/index.js`) | Ruby (`parser.rb`) | Status |
|---|---|---|---|
| XML parsing library | `htmlparser2` (lenient, HTML-aware) | `REXML` (strict XML) | Partial |
| Bare ampersand handling | `htmlparser2` handles natively (`decodeEntities: false`) | Custom `sanitize_bare_ampersands` pre-processing | Match |
| Ending-tag CDATA wrapping | Upstream relies on `htmlparser2` preserving raw HTML for `endingTag` components | Custom `wrap_ending_tags_in_cdata` regex | Match |
| `mj-include` — MJML type | Recursive expansion | Recursive expansion | Match |
| `mj-include` — HTML type | Wraps in `mj-raw` | Wraps in `mj-raw` with CDATA | Match |
| `mj-include` — CSS type | Collects and injects into `mj-head` as `mj-style` | Same behavior | Match |
| `mj-include` — `css-inline="inline"` | Supported | Supported | Match |
| Circular include detection | Tracks `filePath` set | Tracks `included_in` array | Match |
| Missing file handling | Collects error comment instead of crashing | Same behavior | Match |
| Line number tracking | `htmlparser2` provides `startIndex`, converted to line/col | Synthetic `data-mjml-line` injection before parsing | Match |
| File path tracking | Annotations during include expansion | `data-mjml-file` annotations during include expansion | Match |
| `globalAttributes` on AST nodes | `rawAttrs` vs resolved `attributes` distinction | No `rawAttrs` / `globalAttributes` separation — all merged at resolve time | Partial |
| `preprocessors` support | Array of transform functions | Array of callable objects | Match |

### Parser Notes

- The Ruby parser uses REXML which is a strict XML parser. The `htmlparser2` library in npm is much more lenient with malformed HTML. Edge cases with broken/unclosed tags may fail in Ruby but succeed in npm.
- The `rawAttrs` / `globalAttributes` distinction on AST nodes exists in npm but not in Ruby. Ruby resolves attributes at render time via `resolved_attributes()` in the renderer, which effectively produces the same merge order (`mj-all` defaults → `mj-class` attrs → tag defaults → class defaults → node attrs`).
- **Comment handling**: npm wraps HTML comments as `mj-raw` nodes with `content: "<!--...-->"`. Ruby preserves them as `#comment` AST nodes. This means comments inside body content may render differently.
- **Boolean conversion**: npm converts `"true"`/`"false"` attribute strings to actual booleans (`convertBooleans` option). Ruby keeps them as strings. Component code should handle both forms.
- **Bare include wrapping**: Ruby now auto-wraps bare MJML include fragments in `<mjml><mj-body>…</mj-body></mjml>`, matching npm behavior.
- **Ending-tag detection**: npm reads `component.endingTag` from the component registry at runtime. Ruby hardcodes the list in `ENDING_TAGS_FOR_CDATA`. Adding new ending-tag components requires updating the constant.

---

## 3. Components

### 3.1 Head Components

| Component | npm package | Ruby file | Status | Notes |
|---|---|---|---|---|
| `mj-head` | `mjml-head` | `components/head.rb` | Match | Dispatches to child handlers |
| `mj-attributes` | `mjml-head-attributes` | `components/attributes.rb` | Match | `mj-all`, `mj-class`, per-tag defaults |
| `mj-breakpoint` | `mjml-head-breakpoint` | `components/breakpoint.rb` | Match | |
| `mj-font` | `mjml-head-font` | `components/head.rb` (inline) | Match | Handled inline in Head component |
| `mj-preview` | `mjml-head-preview` | `components/head.rb` (inline) | Match | |
| `mj-title` | `mjml-head-title` | `components/head.rb` (inline) | Match | |
| `mj-style` | `mjml-head-style` | `components/head.rb` (inline) | Match | Both regular and `inline="inline"` |
| `mj-html-attributes` | `mjml-head-html-attributes` | `components/html_attributes.rb` | Match | `mj-selector` / `mj-html-attribute` children |

### 3.2 Body Components

| Component | npm package | Ruby file | Status | Notes |
|---|---|---|---|---|
| `mj-body` | `mjml-body` | `components/body.rb` | Match | |
| `mj-section` | `mjml-section` | `components/section.rb` | Match | See section notes |
| `mj-wrapper` | `mjml-wrapper` | `components/section.rb` | Match | Handled in same class; see wrapper notes |
| `mj-column` | `mjml-column` | `components/column.rb` | Match | See column notes |
| `mj-group` | `mjml-group` | `components/group.rb` | Match | |
| `mj-text` | `mjml-text` | `components/text.rb` | Match | |
| `mj-button` | `mjml-button` | `components/button.rb` | Match | |
| `mj-image` | `mjml-image` | `components/image.rb` | Match | See image notes |
| `mj-divider` | `mjml-divider` | `components/divider.rb` | Match | |
| `mj-spacer` | `mjml-spacer` | `components/spacer.rb` | Match | |
| `mj-table` | `mjml-table` | `components/table.rb` | Partial | Structural parsing (not CDATA) |
| `mj-raw` | `mjml-raw` | `components/raw.rb` | Match | Including `position="file-start"` |
| `mj-hero` | `mjml-hero` | `components/hero.rb` | Match | See hero notes |
| `mj-social` | `mjml-social` | `components/social.rb` | Match | See social notes |
| `mj-accordion` | `mjml-accordion` | `components/accordion.rb` | Match | |
| `mj-carousel` | `mjml-carousel` | `components/carousel.rb` | Match | See carousel notes |
| `mj-navbar` | `mjml-navbar` | `components/navbar.rb` | Match | |

### Component-Specific Notes

#### mj-section / mj-wrapper

- **`full-width` mode**: Both npm and Ruby implement the full-width rendering path with background-image support and VML (Outlook) background. VML `v:rect` / `v:fill` output has been matched and regression-tested.
- **`gap` attribute**: npm wrapper supports `gap` for spacing between child sections. Ruby wrapper handles gap via `margin-top` on child sections, matching upstream behavior.
- **Background-image rendering**: Both implementations generate VML `v:fill` and `v:rect` Outlook-specific background markup. Ruby normalizes VML `origin` / `position` number formatting and uses integer `width` attributes in wrapper Outlook child rows, matching upstream output.
- **`border-radius`**: Both support `border-radius` with `overflow:hidden` and `border-collapse:separate`.
- **`direction` attribute**: Both support `direction` for RTL layout. Source order stays mobile-first, the section container emits `direction:rtl`, and child columns keep `direction:ltr`.

#### mj-column

- **Width calculation**: Both npm and Ruby do complex width calculations based on parent section width, column count, and explicit width attributes. Ruby's `compute_column_widths` matches upstream logic.
- **`inner-border` / `inner-border-radius`**: These are Ruby-specific extensions not present in upstream npm. They pass validation and render correctly but aren't upstream features.
- **Media query registration**: npm columns register `addMediaQuery` for responsive width overrides. Ruby uses `context[:column_widths]` for the same purpose, producing equivalent media queries.

#### mj-image

- **Fluid images** (`fluid-on-mobile`): Ruby emits the responsive mobile class and media query, matching npm behavior.
- **`usemap`** attribute: Ruby passes `usemap` through to the rendered `<img>`.
- **`srcset`** / `sizes`**: Ruby passes these through to the rendered `<img>`.

#### mj-social

- **Built-in icon sets**: Both npm and Ruby have matching icon definitions for 17 base networks (facebook, twitter, x, google, pinterest, linkedin, instagram, web, snapchat, youtube, tumblr, github, xing, vimeo, medium, soundcloud, dribbble) plus `-noshare` variants. Regression-tested against upstream definitions.
- **`mj-social-element` sub-component**: npm has `SocialElement` as a separate component class. Ruby handles it inline within the social component, producing equivalent output.
- **Icon modes** (`vertical`, `horizontal`): Both support `mode` attribute for layout direction.
- **`icon-padding`**, **`text-padding`**: Both support all padding sub-attributes.

#### mj-carousel

- **CSS-only implementation**: Both npm and Ruby generate equivalent CSS for carousel state management using radio buttons and adjacent sibling selectors. Regression-tested for radio-driven image visibility, next/previous controls, selected/hovered thumbnails, `noinput` fallback, OWA fallback, and Yahoo-specific rules.
- **`mj-carousel-image` sub-component**: All attributes and rendering match upstream.
- **Thumbnail support**: Both support `thumbnails` attribute with three states: "visible", "hidden", "supported".

#### mj-table

- **Content processing divergence**: npm's `mj-table` passes raw inner HTML through as-is. Ruby normalizes table children: extracts `width` from inline style to HTML attribute, adds `font-family:inherit` to `<td>`/`<th>`/`<table>` elements. This is an intentional Ruby addition, not present upstream.

#### mj-spacer

- **Outer wrapper**: The effective final layout contract matches upstream: the spacer renders as an outer cell carrying padding/background styles with an inner height/line-height `<div>`. The ownership of that outer cell differs in Ruby vs npm (Ruby's spacer component owns the `<tr><td>` wrapper rather than inheriting it from the column), but the rendered structure is layout-equivalent.

#### mj-hero

- **VML background**: Both npm and Ruby generate Outlook-specific VML for background images. Ruby matches upstream integer width output for the hero Outlook table + `v:image` markup. Regression-tested for both the background-image case and the no-background case.
- **`mode`**: Both `fixed-height` and `fluid-height` modes are implemented. Fluid-height uses padding-bottom ratio technique; fixed-height uses direct height attribute.

---

## 4. Validation

| Feature | npm (`mjml-validator`) | Ruby (`validator.rb`) | Status |
|---|---|---|---|
| Required attributes | `validAttributes.js` checks `requiredAttributes` | `REQUIRED_BY_TAG` hash | Match |
| Unknown attribute rejection | `validAttributes.js` | `validate_supported_attributes` | Match |
| Attribute type validation | `validTypes.js` + `type.js` type system | `valid_attribute_value?` | Match |
| Parent-child validation | `validChildren.js` + `dependencies` map | `RULES` hash in `dependencies.rb` | Match |
| Unknown tag detection | `validTag.js` checks component registry | Rejects unknown MJML tags during validation | Match |
| Error format | `{ line, tagName, message, formattedMessage }` | `{ line, file, message, tag_name, formatted_message }` | Match (Ruby adds `file`) |
| Line numbers in errors | Yes | Yes | Match |
| File paths in errors | No (npm doesn't track include file paths in errors) | Yes (Ruby tracks `file` from include expansion) | Match (Ruby is better) |
| `unitWithNegative` type | Upstream `type.js` has separate handling | Ruby `unit()` regex already allows `-?` prefix | Match |

### Dependency Rules

| Tag | npm | Ruby | Issue |
|---|---|---|---|
| `mj-attributes` | `[/^.*^/]` | `[/.*/]` | npm regex is broken (literal `^`). Ruby is more correct |

All ending-tag dependency rules (`mj-raw`, `mj-table`, `mj-text`) are aligned with npm (`[]`). The validator skips child checks for ending-tag components via `Dependencies::ENDING_TAGS`.

### Missing Validation: Unknown Tags

npm's `validTag.js` rejects tags that have no registered component (e.g., `<mj-foo>`). Ruby now mirrors this behavior during validation.

---

## 5. Default Fonts

| npm | Ruby |
|---|---|
| Open Sans, Droid Sans, Lato, Roboto, Ubuntu | Open Sans, Droid Sans, Lato, Roboto, Ubuntu |

Both ship the same 5 default Google Fonts.

---

## 6. Post-Processing Pipeline

The npm pipeline after rendering body content is:

1. `minifyOutlookConditionnals(content)` — strip whitespace inside Outlook conditionals
2. Handle `mj-raw` with `position="file-start"`
3. Apply `mj-html-attributes` via Cheerio (if any) — operates on **body content only**
4. Build skeleton (wraps content in `<!doctype>…<html>…</html>`)
5. CSS inline via Juice (if any `inlineStyle`)
6. `mergeOutlookConditionnals(content)` — merge adjacent Outlook blocks
7. Optional `beautify` / `minify`

The Ruby pipeline is (in `build_html_document`):

1. `minify_outlook_conditionals(content)` — strip whitespace inside Outlook conditionals
2. `apply_html_attributes_to_content(content)` via Nokogiri `DocumentFragment` — operates on **body content only**
3. Build HTML document (skeleton wrapping content in `<!doctype>…<html>…</html>`)
4. `apply_inline_styles(html)` via Nokogiri — CSS inlining with specificity sort
5. `merge_outlook_conditionals(html)` — merge adjacent Outlook blocks
6. Prepend `before_doctype` raw content
7. Optional `strip_comments` / `beautify` / `minify` (in `Compiler#post_process`)

**Pipeline ordering now matches.** Both implementations follow the same sequence: minify conditionals → html-attributes (body only) → skeleton → CSS inline → merge conditionals → post-processing.

**Remaining differences:**
- Ruby uses **Nokogiri** for html-attributes and CSS inlining; npm uses **Cheerio** and **Juice** respectively
- Nokogiri may alter whitespace, attribute ordering, and entity encoding differently from Cheerio
- Juice has specific behaviors around `background` shorthand syncing with `background-color` that the Ruby custom inliner replicates. Juice also syncs CSS `width`/`height` to HTML attributes on TABLE/TD/TH/IMG elements and maps `background-color`→`bgcolor`, `background-image`→`background`, `text-align`→`align`, `vertical-align`→`valign` on table elements — all replicated in `sync_html_attributes!`
- Ruby's `mj-html-attributes` parses body content as a `Nokogiri::HTML::DocumentFragment` (not a full document), minimizing re-serialization side effects

---

## 7. Priority TODO List

### P1 — Functional Gaps (affect rendered output)

- [x] **Pipeline ordering**: `mj-html-attributes` now runs on body content before skeleton generation, while inline CSS still runs after skeleton generation. This matches upstream ordering and prevents html-attribute selectors from mutating `<head>` markup in the final document.
- [x] **Outlook conditional minification**: Implement `minify_outlook_conditionals` before skeleton generation to strip inter-tag whitespace inside `<!--[if …]>` blocks
- [x] **Outlook conditional merging (global)**: Apply `merge_outlook_conditionals` as a global post-processing step after CSS inlining, not just within section rendering
- [x] **Unknown tag validation**: Add a `validate_known_tag` check that rejects tags with no registered component (matching npm's `validTag.js`)

### P2 — Behavioral Parity (may affect edge cases)

- [ ] **Replace Nokogiri post-processing for `mj-html-attributes`**: The Nokogiri HTML parser may re-serialize HTML differently (entity encoding, attribute order, whitespace). Consider an approach that doesn't round-trip through a full HTML parser, or use Nokogiri with `xmlMode`-like settings.
- [ ] **Replace Nokogiri post-processing for inline CSS**: Same concern. The custom CSS inliner works well but the Nokogiri round-trip can introduce subtle markup changes.
- [x] **Verify section/wrapper VML background output**: Matched section/wrapper Outlook background markup more closely to upstream by normalizing VML `origin` / `position` number formatting and using integer `width` attributes in wrapper Outlook child rows, with exact regression coverage for the generated `v:rect` / `v:fill` output.
- [x] **Verify `direction` attribute**: Added regression coverage for `mj-section direction="rtl"` to lock the upstream contract: source order stays mobile-first, the section container emits `direction:rtl`, and child columns keep `direction:ltr` so desktop rendering reverses columns the same way as npm.
- [x] **Verify `fluid-on-mobile` in mj-image**: Ensure the responsive CSS class and media query generation matches npm.
- [x] **Verify hero VML background**: Matched the `mj-hero` Outlook VML wrapper/image formatting to upstream integer width output and added regression coverage for the hero Outlook table + `v:image` markup when a background image is present, plus the no-background case where no VML image should be emitted.
- [x] **Verify carousel CSS output**: Added deterministic regression coverage for the upstream carousel CSS selector/declaration contract, including radio-driven image visibility, next/previous controls, selected/hovered thumbnails, `noinput` fallback, OWA fallback, and Yahoo-specific rules.
- [x] **Social element icon URLs**: Added a regression test covering the full built-in `mj-social` icon/share-url/background map, including `-noshare` variants, to lock Ruby to the vendored upstream definitions.
- [x] **mj-spacer outer wrapper**: Verified the effective final layout contract matches upstream: the spacer renders as an outer cell carrying padding/background styles with an inner height/line-height `<div>`, and does not introduce any extra nested table wrapper. The ownership of that outer cell differs in Ruby vs npm, but the rendered structure is layout-equivalent.
- [x] **mj-table content normalization**: Locked down the intentional normalization behavior with regression coverage for width extraction, `align` / `valign` derivation, `font-family: inherit` on normalized table cells, and nested links inheriting the table font stack.
- [x] **Attribute type precision**: Tightened the remaining upstream-driven validation gaps: `mj-text` now validates `font-size`, `height`, `letter-spacing`, and `line-height` precisely; `mj-table` now validates `cellpadding`, `cellspacing`, `font-size`, `line-height`, `role`, and `width` precisely; `unitWithNegative(...)` is supported for upstream `letter-spacing` attributes (`mj-text`, `mj-button`, `mj-navbar-link`, `mj-accordion-text`); and unitless `line-height` values are accepted for `mj-navbar` / `mj-navbar-link` via upstream `unit(px,%,)` semantics. Earlier strict enums for `mj-hero` `mode`, `mj-style` `inline`, and `mj-navbar` `hamburger` remain in place.
- [x] **Comment rendering**: Preserve HTML comments in rendered output when `keep_comments` is enabled, matching npm body-content behavior.
- [x] **Bare include wrapping**: npm auto-wraps bare MJML fragments (without `<mjml>` root) in `<mjml><mj-body>…</mj-body></mjml>`. Ruby now does the same for include expansion.

### P3 — Feature Gaps (rarely used / nice-to-have)

- [x] **`forceOWADesktop`**: Support `owa="desktop"` attribute on `<mjml>` to emit `[owa]`-prefixed media queries.
- [x] **`printerSupport`**: Support `@media only print` media queries when option is set.
- [x] **`.mjmlrc` config file**: `ConfigFile.load` reads `.mjmlrc` (JSON) for `packages` (Ruby files to require, expected to call `MjmlRb.register_component`) and `options` (default compiler options). CLI loads automatically from working directory.
- [x] **Custom component registration**: `MjmlRb.register_component(klass, dependencies:, ending_tags:)` registers custom component classes. Components must inherit from `MjmlRb::Components::Base` (or implement the same interface). Registered components are picked up by both the renderer and validator.
- [x] **Remove extra `<meta charset="utf-8">`**: The upstream skeleton doesn't include this tag; removing it would make output match more closely.
- [ ] **Consolidate `build_img_tag` in social.rb**: `Social#build_img_tag` (line 364) hand-rolls attribute rendering instead of using the shared `html_attrs` helper. Currently correct (nil-only filtering), but a parallel code path that could diverge.
- [ ] **Consolidate `build_img_tag` in carousel_image.rb**: `CarouselImage#build_img_tag` (line 149) also hand-rolls attribute rendering with `next if attrs[key].nil?`. Same risk of diverging from the shared `html_attrs` logic.

---

## 8. Cross-Cutting Concerns

### Nokogiri Dependency

Both `mj-html-attributes` and `mj-style inline="inline"` use Nokogiri for post-processing. The `mj-html-attributes` step now uses `Nokogiri::HTML::DocumentFragment` on body content only (reducing re-serialization scope), while CSS inlining round-trips the full document through `Nokogiri::HTML` / `Nokogiri::HTML5`. This:
- Adds a native C-extension dependency
- Can alter whitespace, entity encoding, and attribute ordering
- Is the single largest source of markup divergence from npm

Options to address:
1. **Keep Nokogiri** but use it in XML mode (`Nokogiri::XML`) instead of HTML mode to reduce re-serialization changes
2. **Replace with string-based processing** for simple cases (attribute injection, inline style merging)
3. **Accept the divergence** as functionally equivalent — the emails render identically in clients

### Entity Handling

- npm's `htmlparser2` with `decodeEntities: false` preserves HTML entities as-is
- Ruby's REXML decodes entities during parsing; the CDATA wrapping approach for ending-tag components preserves raw HTML including entities
- For non-ending-tag components, entities like `&amp;` may be decoded by REXML and re-encoded differently
- The `sanitize_bare_ampersands` pre-processing handles the most common case (bare `&` in email content)

### Whitespace

- npm and Ruby produce different whitespace in the generated HTML due to different template interpolation approaches
- This is cosmetic and doesn't affect email rendering
- The `beautify`/`minify` options can normalize but aren't commonly used
