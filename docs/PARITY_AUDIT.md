# MJML v5 compatibility audit

Reference: [`mjml@5.4.1`](https://github.com/mjmlio/mjml/releases/tag/v5.4.1),
commit `1c434fcbfd042ddfcb9fa4e0496f7eedf1d90bc7`. Updated 2026-10-16.

The 0.6.0 implementation targets v5 semantics. This document replaces the old
v4.18 audit's broad “Match” claims with bounded, reproducible coverage. Passing
these checks does not establish identical rendering in every email client.

## Verified contracts

| Area | Coverage |
|---|---|
| Includes | Disabled by default; explicit opt-in; canonical string/array allowlists; nested relative MJML; HTML and CSS; CSS cascade order; missing/circular files; encoded traversal, absolute/UNC/drive/null paths and symlink escapes; structured diagnostics |
| Body | One body; body id/class; preview first; article ARIA/lang/dir/background; body-targeted HTML attributes |
| Gutter | Pinned upstream fixtures for px/% widths and gutters, two/three/four columns, mixed units, fractional/odd pixels, mobile stacking, groups, RTL, borders/padding and full width |
| Components | Social borders, raw siblings and inner HTML; arbitrary border radii; hero padding and inner widths; accordion selectors/Outlook controls; numeric image width |
| Source/formatting | Raw operators and whitespace, source comments versus Outlook conditionals, minify precedence, paired ignore regions, CSS template values/properties/blocks, mixed/unbalanced syntax, CSS compaction switch |
| API and CLI | Shared option aliases and conflicts; opt-in config and explicit precedence; file/stdin context; validation without rendering; recursive include watching |
| Registry | Shared class/dependency/ending metadata; later registrations; duplicate-tag rejection; per-compilation parser and renderer state |

`test/reference/v5_cases.json` contains focused reference fragments and semantic
DOM projections. `test/test_v5_support.rb` and `test/test_v5_cli_config.rb` cover
security and Ruby-specific error/API contracts. The existing component golden
fragments continue to cover Outlook/VML and the broader rendering behavior.

## Reproducing the reference checks

```sh
npm ci --prefix test/reference --ignore-scripts
MJML_REFERENCE=1 bundle exec rake test
```

`test/reference/package-lock.json` pins the development oracle and its dependency
graph. The gem includes Ruby runtime files, licenses and documentation; it does
not include the npm reference package or load Node/npm. Run these development
commands from a repository checkout; the gem does not ship the test suite.
Ordinary `bundle exec rake test` checks the committed reference expectations and
skips the live oracle. To deliberately refresh semantic projections from the
pinned reference, run `bundle exec ruby test/reference/update.rb`, then review
its diff. This command never generates expectations from the Ruby compiler.

The CI matrix covers `css_parser` 1.21, 2.x and 3.x on Ruby 3.3, 3.4 and 4.0,
plus a separate pinned MJML reference job. The supported dependency range is
`css_parser >= 1.17, < 4`; the CI floor for the 1.x line is 1.21.

## Downstream browser validation

Maintainer-reported Halalbooking validation, supplied on 2026-10-16, tested
`mjml-rb` commit `90f646e35968fdca3afda58c1f2891a7f7a290d6` (gem 0.6.0)
with `css_parser` 3.3.0. Coverage comprised all eight booking-mailer actions
through eleven representative scenarios, all nine configured locales, and
desktop/mobile widths: 198 exact pixel comparisons, without tolerance or masks.

| Comparison | Result |
|---|---|
| Validated commit versus `313ad6a` (gem 0.6.0 / `css_parser` 2.2.0) | All 198 screenshots pixel-identical |
| Master controls versus the previous control run | All 198 screenshots pixel-identical |
| Validated commit versus downstream master's `mjml-rb` 0.5.2 | 185 pixel-identical; 11 background-only differences below short desktop emails; 2 comparisons restoring a missing space in the Turkish KYC email |

There were no rendering errors, missing images or unstable captures. All 198
generated HTML documents had balanced tags, and all 32 focused downstream
MJML/mailer specs passed.

The 11 background-only differences are explained by v5 body styling/class
ownership. A white HTML-root background applied only in the browser harness
eliminated all eleven differences exactly. No footer markup change was needed.
The two Turkish spacing changes were already present in the earlier v5 run;
switching to `css_parser` 3.3.0 introduced no additional visual changes.

This evidence covers representative Chrome renders, not certification across
email clients. The customer screenshots and source templates remain private;
public examples use synthetic content. These results are a maintainer-supplied
validation record, separate from the repository's reproducible reference suite.

## Local performance check

`ruby -Ilib benchmark/compile.rb` measures warmed compilation and allocated Ruby
objects for one and thirty sections containing text and an image. On Ruby 4.0.1
on the development machine, comparing 0.5.3 with this change gave:

| Template | 0.5.3 ms/compile | 0.6.0 ms/compile | 0.5.3 objects | 0.6.0 objects |
|---|---:|---:|---:|---:|
| One section, 300 iterations | 0.47 | 0.65 | 1,554 | 2,007 |
| Thirty sections, 30 iterations | 8.35 | 8.53 | 32,124 | 33,157 |

These are local samples, not performance guarantees or peak-memory measurements.
Per-call parser/renderer state and option validation add overhead most visible
on small inputs; larger-template cost remained close to the baseline in this run.

## Intentional differences and remaining limits

- The API is synchronous and returns structured `Result` errors instead of
  JavaScript promises/exceptions. Soft issues are exposed as `warnings`.
- Denied includes produce explicit Ruby diagnostics. Upstream 5.4.1 renders the
  denial comment but suppresses the validator error for that type. Ruby freezes
  the initial include allowlist across recursion rather than widening it to
  each included file's directory.
- CSS includes in `mj-head` retain their source position, preserving cascade
  order. Upstream collects CSS includes; this port does not copy that reordering.
- The parser uses strict XML outside ending-tag content. Malformed structural
  MJML accepted by upstream's HTML parser can fail in Ruby. `mj-table` retains
  structural parsing for normalization rather than fully raw ending content.
- The formatter preserves raw regions conservatively and implements CSS
  whitespace compaction, not the full htmlnano/cssnano optimization pipeline.
  Only `minifyCss`/`minifyCSS`/`minify_css` is supported in `minify_options`;
  other minifier settings are rejected explicitly.
- The custom CSS inliner implements common cascade and HTML-attribute syncing,
  but is not Juice. Non-empty `juice_options` and `juice_preserve_tags` raise an
  unsupported-option error. Template CSS intended for later evaluation should
  use non-inline `mj-style` or raw styles; template-driven selector/block
  evaluation in the CSS inliner is unsupported.
- Ruby components replace JavaScript package execution. `.mjmlconfig.js`, npm
  component packages and the browser bundle are unsupported.
- Negative hero widths caused by padding wider than the container are clamped
  to zero in Ruby; upstream currently emits negative widths.
- Watch mode polls known root files and enabled include dependencies; it does
  not discover additional root inputs that later match a startup glob.
- Formatting, quote/entity spelling, attribute order and generated carousel
  identifiers can differ. No automated email-client screenshot certification
  is claimed.

Migration details are in [MIGRATING_TO_V5.md](MIGRATING_TO_V5.md). The original
baseline findings and acceptance goals remain in [the support plan](MJML_V5_SUPPORT_PLAN.md).
