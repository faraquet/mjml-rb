# Architecture

## Purpose

`mjml-rb` is a pure Ruby implementation of the MJML compilation pipeline. The
project does not shell out to the Node.js MJML renderer. Instead it parses MJML
into an internal AST, validates that AST, renders HTML through Ruby component
classes, and applies a small amount of post-processing before returning the
result.

At a high level the system is organized into five layers:

1. Public entry points: library API and CLI.
2. Parsing: XML normalization, preprocessors, include expansion, AST creation.
3. Validation: allowed children, required attributes, supported attributes, and
   basic attribute type checks.
4. Rendering: head/body context assembly plus component-specific HTML output.
5. Result packaging: final HTML string plus structured errors and warnings.

## Public Entry Points

### Library API

The gem entry point is `lib/mjml-rb.rb`.

- `MjmlRb.mjml2html(mjml, options = {})`
  - Main public API.
  - Instantiates `MjmlRb::Compiler`.
  - Returns a hash with `:html`, `:errors`, and `:warnings`.
- `MjmlRb.to_html`
  - Alias of `mjml2html`.

Internally the compiler works with `MjmlRb::Result`, but the top-level module
returns `Result#to_h` for compatibility with the expected `mjml2html` shape.

### CLI

`bin/mjml` delegates to `MjmlRb::CLI`, which supports three main modes:

- Read/compile files.
- Validate files.
- Watch files and recompile them on change.

The CLI accepts both explicit mode flags and stdin/stdout usage. Watch mode is
implemented as a polling loop based on file modification times rather than OS
file notifications.

## Core Compile Flow

`MjmlRb::Compiler` is the orchestrator. `Compiler#compile` follows this flow:

1. Merge default options with call-specific options.
2. Parse MJML into an `AstNode` tree.
3. Run validation unless `validation_level` is `skip`.
4. Stop early when strict validation fails.
5. Render HTML from the AST.
6. Apply post-processing such as comment stripping, beautify, or minify.
7. Return a `Result`.

Default compiler options live in `MjmlRb::Compiler::DEFAULT_OPTIONS`. Important
ones:

- `validation_level`: `soft`, `strict`, or `skip`.
- `keep_comments`: preserve comment nodes through parsing and rendering.
- `ignore_includes`: skip `mj-include` expansion.
- `preprocessors`: callable objects applied to the raw source before parsing.
- `file_path` and `actual_path`: used for include resolution.

Error handling is intentionally forgiving:

- Parse errors are wrapped as structured errors in the result.
- Unexpected runtime errors are also converted into structured errors.
- `warnings` currently exists in the result shape but is not populated by the
  compiler.

## Parsing Layer

`MjmlRb::Parser` converts MJML source into an `AstNode` tree using `Nokogiri::XML`.

### Pre-parse normalization

Before building the XML document, the parser performs several cleanup steps:

- Runs user-provided preprocessors.
- Wraps `mj-raw` contents in CDATA when needed.
- Normalizes HTML void tags so XML parsing can succeed.
- Expands `mj-include` nodes unless includes are disabled.
- Escapes bare `&` characters that are not valid XML entities.

These steps make the parser more tolerant of email-template input that is valid
for MJML or HTML but not strict XML.

### Include expansion

`mj-include` is expanded recursively before AST conversion.

- `type="html"` includes are wrapped into `mj-raw`.
- MJML includes are inserted as parsed XML fragments.
- Paths are resolved against:
  - the directory of `actual_path`
  - `file_path`
  - the current working directory

Include expansion is implemented inside the parser rather than in the renderer,
so downstream stages always operate on a single expanded document tree.

### AST shape

`MjmlRb::AstNode` is the uniform tree structure used by validation and
rendering.

- Element nodes store `tag_name`, `attributes`, `children`, and `line`.
- Text nodes are represented with `tag_name == "#text"`.
- Comment nodes are represented with `tag_name == "#comment"`.

The AST is intentionally small and generic. Component behavior is not embedded
in the node type; it is provided later by the renderer and validator.

## Validation Layer

`MjmlRb::Validator` validates either raw MJML or a prebuilt AST.

### What it validates today

- Root element must be `mjml`.
- A document must contain `mj-body`.
- Child placement must match `MjmlRb::Dependencies::RULES`.
- Some tags require specific attributes.
- Component-declared attributes are checked for support and basic type validity.

Type validation currently covers:

- strings
- colors
- enums
- unit-based values such as `px` and `%`

### How attribute validation works

The validator discovers supported attributes from component classes under
`MjmlRb::Components`. Most components declare `ALLOWED_ATTRIBUTES`, and some
provide `allowed_attributes_for(tag_name)` when multiple tags share the same
class.

This means attribute support is mostly decentralized:

- structure rules live in `lib/mjml-rb/dependencies.rb`
- attribute rules live in component classes
- validation logic lives in `lib/mjml-rb/validator.rb`

That split keeps component behavior close to its validation metadata, but it
also means any new component must be wired into more than one place.

## Rendering Layer

`MjmlRb::Renderer` turns the AST into the final HTML document. This is the
largest part of the system.

### Render entry

`Renderer#render(document, options)`:

1. Finds `mj-head` and `mj-body`.
2. Builds a rendering context from head metadata and options.
3. Collects component-provided head CSS.
4. Renders the body tree.
5. Appends responsive column-width CSS.
6. Builds the final HTML document string.
7. Applies HTML-attribute and inline-style transformations with Nokogiri.

### Rendering context

The renderer passes a mutable `context` hash through component rendering. It is
the main shared state mechanism in the project.

Important context keys include:

- `:title`, `:preview`
- `:breakpoint`
- `:head_raw`, `:head_styles`, `:inline_styles`
- `:html_attributes`
- `:fonts`
- `:global_defaults`, `:tag_defaults`
- `:classes`, `:classes_default`
- `:background_color`, `:container_width`
- `:column_widths`
- `:inherited_mj_class`

This design keeps the component API small, but it also means correctness
depends on components mutating shared state in a disciplined way.

### Head processing

Head nodes are not rendered into HTML directly. Instead supported head
components mutate the context through `handle_head`.

Current head-related responsibilities:

- `mj-title` sets document title.
- `mj-preview` sets preview text.
- `mj-style` contributes either head CSS or inline CSS rules.
- `mj-font` registers font URLs.
- `mj-breakpoint` controls responsive breakpoint CSS.
- `mj-attributes` builds default attribute maps and class maps.
- `mj-html-attributes` registers selector-to-attribute rules.
- `mj-raw` can inject raw markup into `<head>` or before the doctype.

### Component registry

Most renderable tags are implemented as subclasses of `MjmlRb::Components::Base`
and registered explicitly in `Renderer#component_registry`.

Currently implemented as component classes:

- `mj-body`
- `mj-head`, `mj-title`, `mj-preview`, `mj-style`, `mj-font`
- `mj-attributes`, `mj-all`, `mj-class`
- `mj-breakpoint`
- `mj-accordion`, `mj-accordion-element`, `mj-accordion-title`,
  `mj-accordion-text`
- `mj-button`
- `mj-hero`
- `mj-image`
- `mj-navbar`, `mj-navbar-link`
- `mj-raw`
- `mj-text`
- `mj-divider`
- `mj-html-attributes`, `mj-selector`, `mj-html-attribute`
- `mj-table`
- `mj-social`, `mj-social-element`
- `mj-section`, `mj-wrapper`
- `mj-group`
- `mj-column`
- `mj-spacer`

### Component responsibilities

Components are responsible for HTML generation for their tags. The base class
exposes shared renderer helpers such as:

- child rendering
- attribute resolution
- HTML escaping
- raw-inner vs HTML-inner extraction
- style merging helpers

Some components also participate in head behavior by exposing:

- `handle_head`
- `head_style`
- `head_style_tags`

### Attribute resolution order

Resolved attributes for a node are built in this order:

1. global defaults from `mj-all`
2. per-tag defaults from `mj-attributes`
3. direct `mj-class` attributes
4. inherited descendant defaults from parent `mj-class`
5. node attributes from the MJML source

This order is implemented in `Renderer#resolved_attributes`.

### Document assembly

After body rendering, the renderer assembles:

- doctype
- `<html>` with `lang` and `dir`
- font `<link>` tags and `@import` CSS for actually used fonts
- a reset stylesheet plus component CSS
- optional preview block
- body wrapper markup

After string assembly it runs two Nokogiri-based passes:

- apply selector-based HTML attributes from `mj-html-attributes`
- inline CSS from `mj-style inline="inline"`

This is an important architectural detail: the project is not purely
string-based. It renders to HTML as a string, then reparses that HTML for
selector-based mutations.

## Components of Note

Some behaviors are important enough to call out because they shape the rest of
the architecture:

- `Body`
  - Sets the top-level container width and background color in the context.
- `Section`
  - Renders the main MJML section structure, including Outlook conditional
    table wrappers and width calculations for columns/groups.
- `Column`
  - Computes child container widths so inner components such as `mj-image` can
    size themselves correctly.
- `Head`
  - Acts as a dispatcher for supported head child tags.
- `Attributes`
  - Builds the default and class-based styling maps used later by the renderer.
- `HtmlAttributes`
  - Defers selector-based mutations until after full HTML generation.
- `Raw`
  - Preserves raw markup and supports `position="file-start"` before the
    doctype.

## Test Coverage Snapshot

The repository has broader test coverage than the previous version of this
document suggested. Current tests cover:

- compiler behavior and include expansion
- validation
- head features
- HTML attribute injection
- navbar rendering
- column and image sizing details
- `mj-all` / `mj-class` attribute precedence

Tests are still example-based rather than parity-fixture-based. They validate
important local behavior, but they do not yet prove full compatibility with the
upstream JavaScript MJML renderer.

## Extension Workflow

To add a new component safely, the usual steps are:

1. Create a new class under `lib/mjml-rb/components/` that inherits from
   `MjmlRb::Components::Base`.
2. Declare `TAGS` and attribute metadata.
3. Implement `render`.
4. Implement `handle_head` and/or `head_style` if the component affects head
   processing.
5. Register the component in `Renderer#component_registry`.
6. Add parent/child rules to `Dependencies::RULES`.
7. Add tests that cover rendering and validation behavior.

If a tag is allowed by dependency rules but has no renderer implementation, it
may validate successfully but still not produce correct output. That risk now
applies mainly to future dependency-only tags rather than the current carousel
implementation.

## Current Limitations

This architecture is workable and reasonably modular, but several limitations
are visible in the code:

- feature parity with the upstream MJML JavaScript implementation is incomplete
- the renderer relies heavily on a mutable shared context hash
- parser diagnostics are limited and line information is mostly absent
- validation is useful but narrower than upstream MJML validation
- some supported behavior is implemented through post-render DOM mutation rather
  than in a single render pass
- watch mode uses polling and does not track newly added files after startup

## Recommended Next Improvements

1. Add parity fixtures that compare Ruby output with the official MJML output
   for the same inputs.
2. Improve parser and include error diagnostics with line-aware reporting.
3. Continue converting dependency-only tags into actual renderer components.
4. Reduce renderer context coupling where feasible by introducing narrower
   context objects or helper structs.
5. Expand validator rule coverage to match more upstream MJML semantics.
