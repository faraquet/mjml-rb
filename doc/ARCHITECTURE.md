# ARCHITECTURE

## Goal Implemented
Created a **standalone Ruby implementation** with a **pure Ruby pipeline** (no external renderer wrapper).

## What Was Added
- Ruby gem/project scaffold:
  - `Gemfile`
  - `mjml-rb.gemspec`
  - `README.md`
  - `bin/mjml`
- Ruby MJML library entrypoint:
  - `lib/mjml.rb`
- Core pipeline (pure Ruby):
  - `lib/mjml/parser.rb` (XML parse + preprocessors + `mj-include` expansion)
  - `lib/mjml/ast_node.rb` (AST node model)
  - `lib/mjml/renderer.rb` (HTML renderer for core MJML components)
  - `lib/mjml/compiler.rb` (compile flow + validation levels + post-processing)
  - `lib/mjml/validator.rb` (AST validation)
  - `lib/mjml/dependencies.rb` (MJML dependency rules adapted from JS preset)
  - `lib/mjml/migrator.rb` (basic MJML3 -> MJML4 tag migration)
  - `lib/mjml/result.rb`
  - `lib/mjml/version.rb`
- Tests:
  - `test/test_compiler.rb`

## What Was Explicitly Removed
- External renderer dependency and runtime usage.
- Engine abstraction tied to the old renderer wrapper:
  - removed legacy renderer engine implementation
  - removed `lib/mjml/engines/simple_engine.rb`

## Naming Updates
- Gem name is `mjml-rb`.
- Gemspec filename changed to `mjml-rb.gemspec`.
- Lockfile updated accordingly.

## Current Behavior
- `MjmlRb.mjml2html(source, options)` works and returns hash with `:html`, `:errors`, `:warnings`.
- CLI supports key flows:
  - compile (`input -> html`)
  - validate (`--validate`)
  - migrate (`--migrate`)
  - stdin/stdout + file output
  - watch mode (polling-based)
- Validation levels supported: `soft`, `strict`, `skip`.
- Include expansion supports `mj-include` with relative path resolution.

## Test/Verification Status
Executed:
- `ruby -Ilib test/test_compiler.rb`

Result:
- `6 runs, 22 assertions, 0 failures, 0 errors`

## Known Gaps vs Full MJML Parity
This is a strong Ruby foundation, but not full parity with upstream MJML JS yet.

Major remaining gaps:
- Full component parity (advanced components/attributes still incomplete).
- Exact style cascade/defaults semantics vs MJML JS.
- Full `mj-head` behavior parity (`mj-html-attributes`, advanced `mj-style`, etc.).
- More precise output fidelity for Outlook conditionals/minification/beautify edge cases.
- Broader validator parity with JS validator rules/types.

## Suggested Next Work (Priority Order)
1. Implement missing component renderers one-by-one from JS implementations.
2. Expand validator to match JS rules (`validChildren`, `validAttributes`, `validTypes`).
3. Add compatibility fixtures comparing Ruby output to JS output for same MJML inputs.
4. Improve include/preprocessor error reporting with line-aware diagnostics.
5. Add CI for Ruby tests/lint/build.
