# npm ↔ Ruby Parity Audit

Comparison of upstream npm MJML (`.mjml-src/packages/`) against the Ruby port (`lib/mjml-rb/`).
Last updated 2026-03-12.

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
| CSS inlining (`mj-style inline`) | Uses **Juice** library with `juiceOptions`, `juicePreserveTags` | Custom Nokogiri-based inliner with specificity sort | Partial |
| `mj-html-attributes` application | **Cheerio** (`xmlMode: true, decodeEntities: false`), applied **before** skeleton | **Nokogiri** (`Nokogiri::HTML`), applied **after** skeleton | Partial |
| Pipeline ordering | html-attributes → skeleton → Juice → merge conditionals | skeleton → html-attributes → inline CSS → prepend before_doctype | Partial |
| Outlook conditional minification | `minifyOutlookConditionnals()` strips whitespace between tags inside `<!--[if …]>` blocks *before* skeleton | Applied to body content before skeleton generation | Match |
| Outlook conditional merging | `mergeOutlookConditionnals()` merges adjacent `<!--[endif]--><!--[if mso\|IE]>` *after* CSS inlining | Applied globally after CSS inlining | Match |
| Background-color on `<body>` | Skeleton adds `background-color:${backgroundColor}` to `<body style>` | Propagated from `context[:background_color]` to `<body style>` | Match |
| `beautify` / `minify` post-processing | `js-beautify` / `html-minifier` (deprecated, warns) | Regex-based simplistic implementation | Partial |
| `forceOWADesktop` option | Adds `[owa]` prefixed media queries when `owa="desktop"` on `<mjml>` | Supported via conditional OWA media queries | Match |
| `printerSupport` option | Adds `@media only print` media queries | Supported via `printer_support` render option | Match |
| `juiceOptions` / `juicePreserveTags` | Pass-through to Juice | N/A (custom CSS inliner) | Missing |
| `.mjmlrc` config file support | `handleMjmlConfig` reads `.mjmlrc` for packages, options, preprocessors | Not implemented | Missing |
| Custom component registration | `registerComponent()`, presets with `assignComponents` | No plugin/preset system | Missing |

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
| `mj-section` | `mjml-section` | `components/section.rb` | Partial | See section notes |
| `mj-wrapper` | `mjml-wrapper` | `components/section.rb` | Partial | Handled in same class; see wrapper notes |
| `mj-column` | `mjml-column` | `components/column.rb` | Partial | See column notes |
| `mj-group` | `mjml-group` | `components/group.rb` | Partial | |
| `mj-text` | `mjml-text` | `components/text.rb` | Match | |
| `mj-button` | `mjml-button` | `components/button.rb` | Match | |
| `mj-image` | `mjml-image` | `components/image.rb` | Partial | See image notes |
| `mj-divider` | `mjml-divider` | `components/divider.rb` | Match | |
| `mj-spacer` | `mjml-spacer` | `components/spacer.rb` | Match | |
| `mj-table` | `mjml-table` | `components/table.rb` | Partial | Structural parsing (not CDATA) |
| `mj-raw` | `mjml-raw` | `components/raw.rb` | Match | Including `position="file-start"` |
| `mj-hero` | `mjml-hero` | `components/hero.rb` | Partial | |
| `mj-social` | `mjml-social` | `components/social.rb` | Partial | See social notes |
| `mj-accordion` | `mjml-accordion` | `components/accordion.rb` | Match | |
| `mj-carousel` | `mjml-carousel` | `components/carousel.rb` | Partial | See carousel notes |
| `mj-navbar` | `mjml-navbar` | `components/navbar.rb` | Match | |

### Component-Specific Notes

#### mj-section / mj-wrapper

- **`full-width` mode**: npm has a complex full-width rendering path with background-image support and VML (Outlook) background. Ruby implements full-width but VML background specifics may diverge.
- **`gap` attribute**: npm wrapper supports `gap` for spacing between child sections. Ruby section handles gap but should be compared for exact output.
- **Background-image rendering**: npm uses `background-url`, `background-repeat`, `background-size`, `background-position` to generate VML `v:fill` and `v:rect` Outlook-specific background. The Ruby implementation should be verified for exact VML output.
- **`border-radius`**: npm section supports `border-radius`. Verify Ruby parity.
- **`direction` attribute**: npm section supports `direction` for RTL layout, which reverses column order. Verify Ruby parity.

#### mj-column

- **Width calculation**: npm column does complex width calculations based on parent section width, column count, and explicit width attributes. Ruby `compute_column_widths` should match this logic.
- **`inner-border` / `inner-border-radius`**: These are Ruby-specific extensions not present in upstream npm. They pass validation and render correctly but aren't upstream features.
- **Media query registration**: npm columns register `addMediaQuery` for responsive width overrides. Ruby uses `context[:column_widths]` for the same purpose.

#### mj-image

- **Fluid images** (`fluid-on-mobile`): Ruby emits the responsive mobile class and media query, matching npm behavior.
- **`usemap`** attribute: Ruby passes `usemap` through to the rendered `<img>`.
- **`srcset`** / `sizes`**: Ruby passes these through to the rendered `<img>`.

#### mj-social

- **Built-in icon sets**: npm has a comprehensive set of built-in social network icons with image URLs (stored in `SocialElement.js`). Ruby must have matching icon definitions.
- **`mj-social-element` sub-component**: npm has `SocialElement` as a separate component class. Ruby handles it inline within the social component.
- **Icon modes** (`vertical`, `horizontal`): npm supports `mode` attribute for layout. Verify Ruby.
- **`icon-padding`**, **`text-padding`**: Verify all padding sub-attributes match.

#### mj-carousel

- **CSS-only implementation**: npm carousel generates extensive CSS for the carousel animation. Ruby should match the CSS exactly for email client compatibility.
- **`mj-carousel-image` sub-component**: Verify all attributes and rendering match.
- **Thumbnail support**: npm has `thumbnails` attribute with thumbnail rendering. Verify Ruby.

#### mj-table

- **Content processing divergence**: npm's `mj-table` passes raw inner HTML through as-is. Ruby normalizes table children: extracts `width` from inline style to HTML attribute, adds `font-family:inherit` to `<td>`/`<th>`/`<table>` elements. This is an intentional Ruby addition, not present upstream.

#### mj-spacer

- **Outer wrapper**: npm renders just a `<div>` with height/line-height. Ruby wraps it in an outer `<tr><td>` with padding and word-break styles. Verify whether the extra wrapper causes layout differences.

#### mj-hero

- **VML background**: npm hero generates Outlook-specific VML for background images. Verify Ruby matches.
- **`mode`**: `fixed-height` vs `fluid-height`. Verify both modes.

---

## 4. Validation

| Feature | npm (`mjml-validator`) | Ruby (`validator.rb`) | Status |
|---|---|---|---|
| Required attributes | `validAttributes.js` checks `requiredAttributes` | `REQUIRED_BY_TAG` hash | Match |
| Unknown attribute rejection | `validAttributes.js` | `validate_supported_attributes` | Match |
| Attribute type validation | `validTypes.js` + `type.js` type system | `valid_attribute_value?` | Partial |
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

The Ruby pipeline is:

1. Build HTML document (skeleton + content)
2. Apply `mj-html-attributes` via Nokogiri (if any) — operates on **full document**
3. Apply inline CSS via Nokogiri (if any)
4. Prepend `before_doctype` raw content
5. Optional `strip_comments` / `beautify` / `minify`

**Differences:**
- npm applies html-attributes **before** skeleton (body content only); Ruby applies **after** (full document including `<head>`)
- Ruby is missing Outlook minification (step 1) and Outlook merge as global step (step 6)
- Ruby applies `mj-html-attributes` and CSS inlining using Nokogiri; npm uses Cheerio and Juice respectively
- Nokogiri may alter whitespace, attribute ordering, and entity encoding differently from Cheerio
- Juice has specific behaviors around `background` shorthand syncing with `background-color` that the Ruby custom inliner replicates

---

## 7. Priority TODO List

### P1 — Functional Gaps (affect rendered output)

- [ ] **Pipeline ordering**: npm applies `mj-html-attributes` via Cheerio **before** skeleton generation, then applies inline CSS via Juice **after** skeleton. Ruby applies both **after** skeleton. This means `mj-html-attributes` selectors in npm operate on body content only, while in Ruby they operate on the full document including `<head>`. Consider whether reordering is needed or if current behavior is acceptable.
- [x] **Outlook conditional minification**: Implement `minify_outlook_conditionals` before skeleton generation to strip inter-tag whitespace inside `<!--[if …]>` blocks
- [x] **Outlook conditional merging (global)**: Apply `merge_outlook_conditionals` as a global post-processing step after CSS inlining, not just within section rendering
- [x] **Unknown tag validation**: Add a `validate_known_tag` check that rejects tags with no registered component (matching npm's `validTag.js`)

### P2 — Behavioral Parity (may affect edge cases)

- [ ] **Replace Nokogiri post-processing for `mj-html-attributes`**: The Nokogiri HTML parser may re-serialize HTML differently (entity encoding, attribute order, whitespace). Consider an approach that doesn't round-trip through a full HTML parser, or use Nokogiri with `xmlMode`-like settings.
- [ ] **Replace Nokogiri post-processing for inline CSS**: Same concern. The custom CSS inliner works well but the Nokogiri round-trip can introduce subtle markup changes.
- [ ] **Verify section/wrapper VML background output**: Compare Outlook VML background rendering (`v:fill`, `v:rect`, `v:image`) against npm output for `background-url` attributes.
- [ ] **Verify `direction` attribute**: Ensure RTL column reordering in sections matches npm behavior.
- [x] **Verify `fluid-on-mobile` in mj-image**: Ensure the responsive CSS class and media query generation matches npm.
- [ ] **Verify hero VML background**: Compare hero Outlook background rendering.
- [ ] **Verify carousel CSS output**: The CSS-only carousel relies on exact CSS for email client compatibility. Diff against npm output.
- [ ] **Social element icon URLs**: Verify all built-in social network icon image URLs match upstream definitions.
- [ ] **mj-spacer outer wrapper**: Ruby wraps spacer in `<tr><td>` with padding styles; npm renders just a `<div>`. Verify whether this divergence affects layout.
- [ ] **mj-table content normalization**: Ruby adds `font-family:inherit` to td/th and extracts width from style attributes. This is intentional but diverges from npm's raw passthrough. Verify it doesn't cause regressions.
- [ ] **Attribute type precision**: Some Ruby attribute type specs use generic `string` where npm uses precise `unit(px)` or `integer`. Tightening types would improve validation accuracy.
- [ ] **Comment rendering**: npm wraps HTML comments as `mj-raw` nodes; Ruby keeps them as `#comment` nodes. Verify comment rendering in body content matches.
- [x] **Bare include wrapping**: npm auto-wraps bare MJML fragments (without `<mjml>` root) in `<mjml><mj-body>…</mj-body></mjml>`. Ruby now does the same for include expansion.

### P3 — Feature Gaps (rarely used / nice-to-have)

- [x] **`forceOWADesktop`**: Support `owa="desktop"` attribute on `<mjml>` to emit `[owa]`-prefixed media queries.
- [x] **`printerSupport`**: Support `@media only print` media queries when option is set.
- [ ] **`.mjmlrc` config file**: Support reading `.mjmlrc` for default options and custom package registration.
- [ ] **Custom component registration / presets**: Support for `registerComponent()` and preset packages.
- [x] **Remove extra `<meta charset="utf-8">`**: The upstream skeleton doesn't include this tag; removing it would make output match more closely.

---

## 8. Cross-Cutting Concerns

### Nokogiri Dependency

Both `mj-html-attributes` and `mj-style inline="inline"` currently round-trip rendered HTML through Nokogiri for post-processing. This:
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
