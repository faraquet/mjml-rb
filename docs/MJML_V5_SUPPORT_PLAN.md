# MJML v5.4 Support Plan

- Status: proposed
- Target reference: [`mjml@5.4.0`](https://github.com/mjmlio/mjml/releases/tag/v5.4.0)
- Current Ruby baseline: `mjml-rb` 0.5.2, documented against `mjml@4.18.0`
- Last reviewed: 2026-08-07

## Goal

Make the pure-Ruby compiler behaviorally compatible with the tagged MJML
v5.4.0 release without adding a Node.js runtime dependency.

Compatibility means:

- equivalent public compiler and CLI semantics;
- equivalent validation and include diagnostics;
- equivalent HTML structure and email-client behavior for critical markup;
- v5 security defaults, especially for `mj-include`; and
- a repeatable differential test suite against exactly `mjml@5.4.0`.

Exact byte-for-byte HTML is not a general requirement. Attribute order and
non-functional whitespace may differ, but Outlook conditionals, VML, CSS,
accessibility markup, widths, and option behavior must be equivalent.

## Recommended release policy

- Keep `0.5.x` as the MJML v4 compatibility line.
- Ship v5 semantics in `0.6.0`, with the breaking defaults called out in the
  changelog and migration guide.
- Do not add a long-lived v4/v5 runtime switch. It would duplicate parser,
  validation, and rendering branches and make parity harder to prove.
- Pin `mjml@5.4.0` only in development/CI as the reference oracle. The gem
  remains pure Ruby at runtime.

There are no new core component tags between v4.18.0 and v5.4.0. The migration
is primarily about security defaults, document structure, component attributes
and layout, configuration, and post-processing. The authoritative scope is the
[v4.18.0...v5.4.0 comparison](https://github.com/mjmlio/mjml/compare/v4.18.0...v5.4.0).

## Baseline audit: fix before claiming v5 support

The current test suite passes, but differential probes against the official
compiler found the following correctness and consistency defects. Fix these
before changing golden fixtures to v5; otherwise the migration can hide
pre-existing regressions.

Baseline verification: `bundle exec rake test` completed with 589 runs, 2,284
assertions, 0 failures, 0 errors, and 1 skip.

### Release blockers

| Priority | Location | Confirmed behavior | Required change |
|---|---|---|---|
| P1 | `lib/mjml-rb/compiler.rb:104-113` | `keep_comments: false` deletes every generated MSO/IE conditional and `OfficeDocumentSettings`, breaking Outlook layout. | Remove global comment stripping. Drop source comment nodes during parsing while always preserving generated conditionals. |
| P1 | `lib/mjml-rb/compiler.rb:8-17`, `lib/mjml-rb/parser.rb:391-403` | Includes are enabled by default and an absolute or traversing path can read any process-readable file. | Adopt the v5 disabled-by-default include policy and canonical allowlisted roots described below. |
| P1 | `lib/mjml-rb/cli.rb:189-197` | File compilation does not pass the input filename as `actual_path`/`file_path`, so a same-directory relative include is resolved against the process working directory and omitted. | Merge per-input path context into compiler options, including watch mode. |
| P1 | `lib/mjml-rb/parser.rb:84-168` | CSS includes are visited in reverse, collected, and appended to `mj-head`; this reverses include order and moves styles away from their source position. A later blue rule can incorrectly lose to an earlier red rule. | Replace each CSS include in place with its corresponding `mj-style` node and preserve source order. |
| P1 | `lib/mjml-rb/compiler.rb:115-123` | Regex minification collapses significant whitespace inside `<pre>` and raw content. | Replace it with token/HTML-aware processing that protects raw blocks, preformatted elements, template tokens, conditionals, and `htmlmin:ignore` regions. |
| P1 | `lib/mjml-rb/renderer.rb:223-248` | When one column has an explicit width, remaining width is divided among unspecified columns. Upstream gives every unspecified sibling `100 / sibling_count`; `[30%, unset]` must be `[30%, 50%]`, not `[30%, 70%]`. | Base every unspecified width on the total non-raw sibling count. Add percentage and pixel mixed-width fixtures. |
| P1 | `lib/mjml-rb/components/section.rb:511-548`, `lib/mjml-rb/components/section.rb:691-715`, `lib/mjml-rb/components/social.rb:183-233` | `mj-raw` siblings are silently dropped from sections, wrappers, and social blocks whenever a normal child exists. | Iterate original children. Apply layout wrappers only to non-raw children and render raw children directly. |
| P1 | `lib/mjml-rb/parser.rb:13-19`, `lib/mjml-rb/components/social.rb:328-354` | `mj-social-element` is not registered as an ending tag; nested HTML is validated as MJML and then escaped as text. | Centralize ending-tag metadata and render the element's raw inner HTML without escaping. |

### Additional correctness debt

| Priority | Location | Confirmed behavior | Required change |
|---|---|---|---|
| P2 | `lib/mjml-rb/parser.rb:48-60` | With `ignore_includes: true`, the unexpanded `mj-include` remains in the AST and strict validation rejects it. Official v5 silently omits ignored includes. | Remove ignored include nodes during parsing before validation. |
| P2 | `lib/mjml-rb/components/image.rb:170-175` | An image with both explicit width and non-auto height emits `width="auto"`; upstream emits the numeric content width. | Remove the height-dependent special case and test Outlook-oriented width output. |
| P2 | `lib/mjml-rb/components/table.rb:115-129` | Comments inside `mj-table`, including MSO conditionals, are always discarded even when comments are kept. | Preserve serialized comments; source-comment policy belongs in the parser. |
| P2 | `lib/mjml-rb/components/accordion.rb:219-220`, `lib/mjml-rb/components/accordion.rb:253-254` | Accordion checkboxes and interactive icons are emitted unconditionally, while upstream hides them from Outlook with negated-MSO comments. | Restore the `<!--[if !mso | IE]><!-->` wrappers around unsupported interactive controls. |
| P2 | `lib/mjml-rb/components/accordion.rb:223-257` | `css-class` on `mj-accordion-title` is accepted but not rendered on the title cell. | Apply the class to the same element as the reference compiler. |
| P2 | `lib/mjml-rb/components/section.rb:79-83` | Padding width math recognizes only pixels even though section/wrapper schemas accept percentages. | Parse the numeric magnitude of every allowed unit and add percentage-padding width fixtures. |
| P2 | `lib/mjml-rb/validator.rb:107-110` | A known component with an empty allowed-attribute schema skips unknown-attribute validation, so strict mode accepts values such as `mj-title typo="x"`. | Distinguish an empty schema from an explicit allow-any schema. |
| P2 | `lib/mjml-rb/parser.rb:13-19`, `lib/mjml-rb/component_registry.rb:13-20` | Custom ending tags affect validation but not the parser's hard-coded CDATA wrapping. Raw text such as `A < B` then fails XML parsing. | Derive parser ending-tag handling from central registry metadata, retaining explicit structural exceptions such as `mj-table`. |
| P2 | `lib/mjml-rb/component_registry.rb:57-70`, `lib/mjml-rb/renderer.rb:628-659` | A warmed compiler does not see later component registrations, and validator/renderer precedence differs when a custom tag collides with a built-in. | Add a registry revision, invalidate renderer caches, and either reject duplicate tags or apply one documented precedence everywhere. |
| P2 | `lib/mjml-rb/parser.rb:296-303`, `lib/mjml-rb/parser.rb:355-359` | Bare-ampersand sanitization mutates ending-tag content; for example, raw script `a && b` becomes `a &amp;&amp; b`. | Sanitize only XML text/attributes, never bytes already protected as raw/CDATA content. |
| P2 | `lib/mjml-rb/compiler.rb:130-133`, `lib/mjml-rb/config_file.rb:31-34`, `lib/mjml-rb/cli.rb:51-61` | Official camelCase keys such as `keepComments` are rejected, including keys loaded from config, and the CLI does not consistently turn these failures into a controlled exit. | Add one option canonicalizer shared by library, CLI, and config loading; normalize errors to `ConfigError`/exit 1. |
| P2 | `lib/mjml-rb/cli.rb:189-220` | `mjml --validate` compiles and prints/writes HTML. The reference CLI only parses/validates and is silent on valid input. | Add a validate-only path and prohibit output generation in that mode. |
| P2 | `lib/mjml-rb/validator.rb:18-30`, `lib/mjml-rb/validator.rb:45-53` | Calling `Validator` directly with a missing include loses `Parser#include_errors` and reports a clean strict result. | Return a parse result containing AST and diagnostics, then make both `Compiler` and `Validator` consume it. |
| P2 | `lib/mjml-rb/parser.rb:111-115`, `lib/mjml-rb/compiler.rb:136-159` | Include diagnostics collect `file` and `tag_name`, then discard them while building the public result. Nokogiri parse line data is also lost. | Carry structured location fields through a parse result instead of mutable parser state. |

The claims in `docs/PARITY_AUDIT.md` for column width, social ending-tag
behavior, CSS include order, and `.mjmlrc` parity should be corrected as each
issue is resolved. The README's “all components are implemented and tested”
claim should also be reconciled with the load-time experimental warning.

## V5 implementation scope

### 1. Secure include model

This is the first implementation phase because it changes the default and
closes a local-file disclosure risk when untrusted MJML is compiled. The
[v5 parser](https://github.com/mjmlio/mjml/blob/v5.4.0/packages/mjml-parser-xml/src/index.js)
is the behavioral reference.

- Change `ignore_includes`/`ignoreIncludes` default from `false` to `true`.
- Add `include_path`/`includePath`, accepting a string or array of roots.
- Add CLI `allowIncludes`; it maps to `ignore_includes: false`.
- When includes are enabled, make the template's canonical `file_path` root
  and explicit canonical `include_path` roots the only readable locations.
- Resolve and compare `realpath` values so `..` and symlink escapes cannot
  leave an allowed root.
- Reject absolute, UNC, drive-letter, null-byte, and repeatedly URL-encoded
  traversal attempts when they escape the allowlist.
- Preserve relative resolution for nested includes by updating `actual_path`
  to the included file and `file_path` to its directory.
- Preserve MJML, HTML, and CSS include types, inline CSS behavior, source
  order, missing-file diagnostics, and circular-include detection.
- Omit ignored includes silently. For an enabled but denied include, emit
  `<!-- mj-include denied -->` and a structured `include-denied` diagnostic.
- Watch enabled recursive include dependencies, not only the root input file.

### 2. Move HTML `<body>` ownership to `mj-body`

Follow the tagged
[`mj-body`](https://github.com/mjmlio/mjml/blob/v5.4.0/packages/mjml-body/src/index.js)
and [skeleton](https://github.com/mjmlio/mjml/blob/v5.4.0/packages/mjml-core/src/helpers/skeleton.js)
implementations rather than the initial v5 release prose where they differ.

- Add `id: string` to `mj-body`.
- Render the actual `<body>` from `Components::Body`.
- Put `id`, `css-class`, word spacing, and body background on `<body>`.
- Render preview as the first body child.
- Keep the accessibility wrapper inside the body with `aria-label` when a
  title exists, `aria-roledescription="email"`, `role="article"`, `lang`,
  `dir`, word spacing, and background styling.
- Remove body and preview generation from the global skeleton.
- Ensure `mj-html-attributes` selectors can target the real body without
  creating a second body element.

### 3. Component and validation changes

| Component/area | V5.4 behavior to implement |
|---|---|
| `mj-section` | Add `gutter: unit(px,%)`. Propagate gutter/direction and group context; reduce desktop column widths; apply horizontal edge-aware gutter padding in normal and Outlook output; convert regular mobile columns to vertical gaps; preserve horizontal `mj-group` layout; reverse edges for RTL; and normalize mixed-unit/odd-pixel output deterministically. Use the tagged [`mj-section`](https://github.com/mjmlio/mjml/blob/v5.4.0/packages/mjml-section/src/index.js) and [`mj-column`](https://github.com/mjmlio/mjml/blob/v5.4.0/packages/mjml-column/src/index.js) behavior. |
| `mj-social`, `mj-social-element` | Add `border: string`, default element border to `0`, cascade the parent value, allow a child override, and render it on the icon image. See [`mj-social`](https://github.com/mjmlio/mjml/blob/v5.4.0/packages/mjml-social/src/Social.js) and [`mj-social-element`](https://github.com/mjmlio/mjml/blob/v5.4.0/packages/mjml-social/src/SocialElement.js). |
| Border radius | Change every border-radius schema to `string`, including column and inner-column, image, carousel and thumbnail, social and social element, section, hero, and button. Accept mixed units and slash syntax. |
| `mj-hero` | Remove `container-background-color`; apply `inner-padding*` to Outlook and non-Outlook content; pass the padding-reduced width to children and the Outlook inner table. Match the tagged [`mj-hero`](https://github.com/mjmlio/mjml/blob/v5.4.0/packages/mjml-hero/src/index.js). |
| `mj-accordion` | Replace legacy `input.mj-accordion-checkbox` selectors with `.mj-accordion-checkbox[type="checkbox"]` where v5 does so. |
| Required attributes | Remove Ruby-only required checks for `mj-image`, `mj-font`, and `mj-include` unless the tagged v5 validator produces the same diagnostic. V5.4 strict compilation accepts an empty `mj-image` and `mj-font`. |
| Component metadata | Use one registry/manifest for tag class, allowed attributes, ending-tag status, dependencies, head styles, and cache revision. Parser, validator, and renderer must not carry divergent copies. |

The media-query registry currently records only responsive width. Extend it to
record gutter padding and grouped/RTL variants without making every component
mutate a shared ad hoc hash.

### 4. Post-processing and template safety

MJML v5 replaced its old minifier with htmlnano/cssnano and added template
syntax protection. Ruby does not need to use the same libraries, but must match
their observable contract.

- Make minify win when both `minify` and `beautify` are true.
- Preserve MSO/IE conditional comments regardless of `keep_comments`.
- Remove only source comments when `keep_comments` is false.
- Protect `<pre>`, `<textarea>`, raw/ending-tag content, script/style content,
  VML, file-start raw content, and significant whitespace.
- Support paired `<!-- htmlmin:ignore -->` regions; preserve their content
  verbatim during minification and remove only the markers during beautifying.
- Add `minify_options`/`minifyOptions`, including CSS-minification control and
  the legacy `minifyCSS` alias expected by v5.
- Add `sanitize_styles`/`sanitizeStyles`,
  `template_syntax`/`templateSyntax`, and
  `allow_mixed_syntax`/`allowMixedSyntax`.
- Protect and restore template variables in CSS values, property names, and
  blocks. Default delimiters are `{{ ... }}` and `[[ ... ]]`.
- Return an actionable error for unbalanced or disallowed mixed syntax; do not
  silently mutate a template token.

Keep the Ruby API synchronous. The JavaScript reference becoming asynchronous
because of its minifier is an implementation detail, not a compatibility
requirement.

### 5. Public API, config, and CLI

Create a single option schema and canonicalization function. Ruby snake_case is
the documented native form, while upstream camelCase is accepted as an alias.
If both spellings are supplied with different values, raise a clear conflict
error instead of depending on hash order.

| Ruby key | Upstream alias | V5.4 default |
|---|---|---|
| `keep_comments` | `keepComments` | `true` |
| `ignore_includes` | `ignoreIncludes` | `true` |
| `include_path` | `includePath` | none |
| `validation_level` | `validationLevel` | `soft` |
| `file_path` | `filePath` | `.` |
| `actual_path` | `actualPath` | `.` |
| `printer_support` | `printerSupport` | `false` |
| `minify_options` | `minifyOptions` | implementation defaults |
| `sanitize_styles` | `sanitizeStyles` | `false` |
| `template_syntax` | `templateSyntax` | `{{ }}` and `[[ ]]` |
| `allow_mixed_syntax` | `allowMixedSyntax` | `false` |
| `mjml_config_path` | `mjmlConfigPath` | none |
| `use_mjml_config_options` | `useMjmlConfigOptions` | `false` |
| `juice_options` | `juiceOptions` | `{}` |
| `juice_preserve_tags` | `juicePreserveTags` | none |

For Juice-specific options, either implement equivalent behavior in the custom
CSS inliner or return an explicit unsupported-option error. Silently accepting
and ignoring them would not be compatible.

Configuration and CLI work:

- Discover JSON `.mjmlconfig` and keep `.mjmlrc` as a documented legacy alias.
- Do not execute `.mjmlconfig.js` in Ruby. Return a clear unsupported-format
  error and document Ruby custom-component registration as the alternative.
- Apply config options only when requested by `use_mjml_config_options`, while
  explicit call/CLI options take precedence. Deep-merge `minify_options`.
- Preserve preprocessors ordering and reject non-object config roots cleanly.
- Give every file input its own `file_path` and `actual_path` context.
- Add stdin file-path support for include resolution.
- Make `--validate` parse and validate only; valid input produces no HTML.
- Make watch mode observe enabled recursive include dependencies and update
  dependency watches when the include graph changes.

### 6. Documentation and compatibility metadata

- Add a constant such as `MJML_COMPATIBILITY_VERSION = "5.4.0"` and expose it
  in the library/CLI version output.
- Update `README.md`, `docs/USAGE.md`, `docs/ARCHITECTURE.md`, and
  `docs/PARITY_AUDIT.md` from v4.18 to v5.4 semantics.
- Add a migration section covering the include default, `include_path`, body
  structure/class placement, formatter changes, and looser border radii.
- State that `.mjmlconfig.js`, JavaScript component packages, the browser
  bundle, Node-version policy, and removed `mjml-migrate` tooling are outside
  the scope of this pure-Ruby port.
- Replace broad parity claims with the exact reference tag and the known
  unsupported-option list.

## Delivery phases

Each phase should land with its own differential fixtures. Do not update all
snapshots in one commit.

1. **Lock the oracle and baseline**
   - Pin `mjml@5.4.0` in a development-only differential harness.
   - Convert the baseline defects above into failing tests.
   - Record normalized v4 and v5 outputs for high-risk templates.
2. **Fix current correctness defects**
   - Fix Outlook comments, include file context/order, column widths, raw-child
     loss, ending-tag metadata, raw preservation, and registry invalidation.
3. **Implement v5 include security and option aliases**
   - Change the default, add allowlisted roots, denial diagnostics, CLI
     `allowIncludes`, and traversal/symlink coverage.
4. **Move body ownership**
   - Refactor body/skeleton responsibilities and add outer-HTML fixtures.
5. **Port component deltas**
   - Border-radius schemas, hero, accordion, social border, then section gutter.
6. **Replace post-processing**
   - Safe comment handling, formatter/minifier, template sanitization, and
     `htmlmin:ignore`.
7. **Align config and CLI**
   - `.mjmlconfig`, per-file context, validate-only behavior, and include-aware
     watch mode.
8. **Document, benchmark, and release**
   - Update compatibility docs, run the full oracle matrix, benchmark common
     templates, and publish the v4-to-v5 migration notes.

## Acceptance matrix

| Area | Required cases |
|---|---|
| Includes | Default ignored; explicitly enabled local include; string/array allowlist; MJML/HTML/CSS; nested relative includes; inline CSS order; missing and circular includes; absolute/UNC/drive/null/encoded traversal denied; symlink escape denied; structured diagnostics. |
| Body | Exactly one body; id/class on body; preview first; ARIA/lang/dir on the inner div; title omission; background placement; body-targeted HTML attributes. |
| Gutter | Two/three/four columns; px/% gutter; implicit and explicit px/% widths; mixed units; odd pixels; mobile stacking; grouped columns; RTL; borders/padding/full width; Outlook markup. |
| Social | Raw sibling; raw inner HTML; default border; parent cascade; child override; horizontal and vertical modes. |
| Radius | Multiple values, mixed units, and slash syntax across every radius-bearing component. |
| Hero | Shorthand/directional outer padding; inner padding in all clients; padding-reduced child/Outlook width; removed attribute validation. |
| Post-processing | Source comments versus generated conditionals; raw/pre whitespace; multiple ignore pairs; file-start content; template variables in CSS values/properties/blocks; multiline, mixed, and unbalanced delimiters; CSS minification disabled. |
| API/config/CLI | camelCase/snake_case equivalence and conflicts; config precedence; input-relative include; stdin context; validate emits no HTML; watch updates after include-graph changes. |
| Registry | Register before/after first compile; custom ending tags; duplicate-tag policy; repeated and concurrent compilation isolation. |
| Regression | Existing component fixtures; strict/soft/skip validation; Outlook/VML snapshots; malformed input; performance and memory bounds. |

Differential comparisons should use:

- exact fragments for critical Outlook, VML, body, and diagnostic contracts;
- normalized DOM comparisons for general markup;
- parsed CSS/media-query comparisons for responsive behavior; and
- exact result classification and CLI exit codes for validation/configuration.

## Upstream tests to port

- [Include defaults](https://github.com/mjmlio/mjml/blob/v5.4.0/packages/mjml/test/ignore-includes.test.js)
- [Include roots and types](https://github.com/mjmlio/mjml/blob/v5.4.0/packages/mjml/test/include-path.test.js)
- [Include security](https://github.com/mjmlio/mjml/blob/v5.4.0/packages/mjml/test/include-path-security.test.js)
- [Traversal handling](https://github.com/mjmlio/mjml/blob/v5.4.0/packages/mjml/test/include-path-traversal.test.js)
- [Section gutter](https://github.com/mjmlio/mjml/blob/v5.4.0/packages/mjml/test/section-gutter.test.js)
- [Social border](https://github.com/mjmlio/mjml/blob/v5.4.0/packages/mjml/test/social-border.test.js)
- [Border-radius strings](https://github.com/mjmlio/mjml/blob/v5.4.0/packages/mjml/test/border-radius-string.test.js)
- [Hero padding width](https://github.com/mjmlio/mjml/blob/v5.4.0/packages/mjml/test/hero-padding-inner-width.test.js)
- [Template syntax sanitization](https://github.com/mjmlio/mjml/blob/v5.4.0/packages/mjml/test/template-syntax-sanitization.test.js)
- [`htmlmin:ignore`](https://github.com/mjmlio/mjml/blob/v5.4.0/packages/mjml/test/htmlmin-ignore.test.js)
- [Beautifier output](https://github.com/mjmlio/mjml/blob/v5.4.0/packages/mjml/test/beautify-output.test.js)

## Definition of done

V5 support is complete only when all of the following are true:

- the baseline audit issues are fixed or explicitly documented as unsupported;
- every v5 option is implemented or rejected explicitly rather than ignored;
- the security suite proves includes cannot escape canonical allowed roots;
- the component and CLI acceptance matrices pass against `mjml@5.4.0`;
- generated Outlook conditionals and VML survive every option combination;
- the existing Ruby suite remains green;
- documentation names the exact compatibility tag and migration breakages; and
- no Node.js package is required at gem runtime.
