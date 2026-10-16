# Migrating to MJML v5

`mjml-rb` 0.6.0 targets **MJML 5.4.1**. The 0.5.x line retains v4 behavior.
There is no v4/v5 runtime switch. The library remains synchronous and requires
no Node.js packages at runtime.

Requires Ruby >= 3.3, `css_parser` >= 1.17 and < 4, and Nokogiri >= 1.13.
The CI matrix covers `css_parser` 1.21, 2.x and 3.x on Ruby 3.3, 3.4 and 4.0.

## Includes require opt-in

`mj-include` is now silently omitted by default, including in strict validation.
Enable it only for templates that need local files:

```ruby
MjmlRb.mjml2html(source,
  ignore_includes: false,
  file_path: File.dirname(template_path),
  actual_path: template_path,
  include_path: ["../shared"]
)
```

```sh
mjml templates/email.mjml --config.allowIncludes -o email.html
mjml --stdin --filePath templates --config.allowIncludes < templates/email.mjml
```

Paths resolve from `file_path`; CLI file inputs supply their own directory.
Nested includes resolve from the included file's directory. The original
canonical root and explicit `include_path` directories define the allowlist;
nested includes do not expand it. `include_path` accepts a string or an array,
and relative roots resolve against the original `file_path`.

Absolute paths, Windows drive paths, UNC paths, null bytes, and traversal or
symlink escapes are denied. Encoded paths are decoded before checking. Denied
includes produce `<!-- mj-include denied -->` and a structured `include-denied`
diagnostic: a warning in soft/skip mode, an error in strict mode. This is more
explicit than upstream 5.4.1, which omits a validation error for denied includes.
Missing allowed files still produce include diagnostics. Watch mode tracks
recursive enabled dependencies, including deletion, recreation and graph changes.

## HTML and layout changes

- `mj-body` owns the HTML `<body>`. Its `id` and `css-class` are on that element;
  update selectors that previously targeted the inner article div. The preview
  is the first body child. ARIA, language and direction remain on the article.
- `mj-section gutter="20px"` or `gutter="4%"` adds responsive column spacing,
  including edge-aware Outlook padding, RTL and non-stacking groups.
- An unspecified column gets `100 / sibling_count` percent. An explicit `30%`
  column next to an unspecified column now produces `30%` and `50%`.
- `mj-social` and `mj-social-element` accept `border`; icons default to `0`.
- Border radii accept arbitrary CSS strings, including mixed units and `/`.
- `mj-hero` no longer accepts `container-background-color`. Its Outlook inner
  table and child width account for outer horizontal padding; inner padding
  appears in both Outlook and normal markup.
- Empty `mj-image` and `mj-font` no longer trigger Ruby-only required checks.

### Backgrounds in browser previews

CSS applied through `mj-body`'s `css-class` now targets the actual HTML `<body>`.
Its background can paint the browser canvas below the content of a short email;
the inner article also receives the background colour set on `mj-body`.
Review both the body and any wrapper selectors when comparing v4 and v5 output.

In the maintainer's downstream Chrome comparisons, all 11 background-only
differences disappeared exactly when the browser harness set a white HTML-root
background. This was a diagnostic control applied only in the browser harness.
No footer markup change was needed. See the [validation record](PARITY_AUDIT.md#downstream-browser-validation)
for the full scope and results.

## Formatting and source preservation

`keep_comments: false` removes source HTML comments while preserving Outlook
conditionals. Ending-tag content stays raw: bare ampersands, HTML void-tag
spelling and script operators are no longer rewritten for XML parsing.

`minify` takes precedence over `beautify`. The Ruby formatter conservatively
compacts markup and CSS while preserving raw content, preformatted elements,
script text, template tokens, VML and paired `htmlmin:ignore` regions. Ignore
markers are removed from output. Whitespace and CSS optimizations are not
byte-identical to upstream htmlnano/cssnano.

`minify_options: {minify_css: false}` disables CSS compaction. `minifyCss` and the
legacy `minifyCSS` spelling are accepted. Other htmlnano options are rejected.
Use `sanitize_styles: true` to validate template tokens in CSS. Default token
pairs are `{{ ... }}` and `[[ ... ]]`; `template_syntax` accepts an array of
`{prefix:, suffix:}` objects. Unbalanced tokens and mixed block/property/value
syntax report errors; `allow_mixed_syntax: true` enables mixed syntax.

## Options, configuration and extensions

Snake_case, camelCase and dashed option keys are accepted. Conflicting aliases
in the same option layer raise `ArgumentError`; CLI errors return exit status 1.
Boolean options require Ruby booleans. JSON `.mjmlconfig` is preferred;
`.mjmlrc` remains a legacy alias. Config options apply only with
`use_mjml_config_options: true` (CLI `--config.useMjmlConfigOptions`). Explicit
constructor/call/CLI options win. `minify_options` merges by key.

`Compiler#validate` and CLI `--validate` parse and validate without rendering.
Valid CLI validation emits no HTML and does not write output files.
`Result#dependencies` exposes enabled include dependencies without changing the
existing `{html:, errors:, warnings:}` hash API.

Custom components use `MjmlRb.register_component`. Ending-tag metadata is shared
by parsing and validation, and later registrations are visible to existing
compilers. Registering a different class for an existing tag raises an error.

Non-empty `juice_options` and `juice_preserve_tags` are explicitly unsupported.
JavaScript `.mjmlconfig.js` and component packages, browser bundles, Node version
policy and removed `mjml-migrate` tooling are outside this Ruby port's scope.
See [the compatibility audit](PARITY_AUDIT.md) for other known differences.
