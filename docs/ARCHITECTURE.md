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
3. Validation: document structure, allowed children, supported attributes, and
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

1. Canonicalize aliases with `Options`, then merge defaults, opted-in config, constructor and call options.
2. Create a per-call parser and a `ParseResult` containing AST, diagnostics and include dependencies.
3. Run validation unless `validation_level` is `skip`.
4. Stop early when strict validation fails.
5. Render HTML from the AST.
6. Run the conservative `Formatter`; source comments were already handled by parsing.
7. Return a `Result`.

Default compiler options live in `MjmlRb::Compiler::DEFAULT_OPTIONS`. Important
ones:

- `validation_level`: `soft`, `strict`, or `skip`.
- `keep_comments`: preserve comment nodes through parsing and rendering.
- `ignore_includes`: defaults to true; omitted includes disappear before validation.
- `include_path`: extra canonical allowed roots for explicitly enabled includes.
- `preprocessors`: callable objects applied to the raw source before parsing.
- `file_path` and `actual_path`: used for include resolution.

Error handling is intentionally forgiving:

- Parse errors are wrapped as structured errors in the result.
- Unexpected runtime errors are also converted into structured errors.
- Soft validation and include issues populate `warnings`; strict issues populate `errors`.

## Parsing Layer

`MjmlRb::Parser` converts MJML source into a Nokogiri XML node tree.

### Pre-parse normalization

Before building the XML document, the parser performs several cleanup steps:

- Runs user-provided preprocessors.
- Wraps registered ending-tag content in CDATA; structural exceptions are `mj-table` and `mj-carousel-image`.
- Normalizes HTML void tags so XML parsing can succeed.
- Expands `mj-include` nodes unless includes are disabled.
- Escapes bare `&` only outside protected CDATA.

These steps make the parser more tolerant of email-template input that is valid
for MJML or HTML but not strict XML.

### Include expansion

`mj-include` is expanded recursively before AST conversion.

- `type="html"` includes are wrapped into `mj-raw`.
- MJML includes are inserted as parsed XML fragments.
- Paths resolve against `file_path`, updated to the including directory during recursion.
- The original realpath root plus explicit `include_path` roots remain fixed.
- Canonical containment rejects traversal and symlink escapes before reading.
- CSS includes in the head are replaced in place.
- `ParseResult` carries file, line, tag, diagnostic type and dependencies.

Include expansion is implemented inside the parser rather than in the renderer,
so downstream stages always operate on a single expanded document tree.

### Node tree

The parser returns the root `Nokogiri::XML::Node` directly. A small
`MjmlRb::NodeCompat` module is prepended to `Nokogiri::XML::Node` to add
convenience methods (`tag_name` as an alias for `name`, and `file` to read
the `data-mjml-file` annotation).

- Element nodes are `Nokogiri::XML::Element` instances.
- Text nodes respond to `text?` and store their content in `content`.
- Comment nodes respond to `comment?`.
- Ending-tag components (e.g. `mj-text`, `mj-button`) are marked with a
  `data-mjml-ending-tag` attribute; their raw HTML is preserved as CDATA children.

Component behavior is not embedded in the node type; it is provided later by
the renderer and validator.

## Validation Layer

`MjmlRb::Validator` validates either raw MJML or a prebuilt AST.

### What it validates today

- Root element must be `mjml`.
- A document must contain `mj-body`.
- Child placement must match `MjmlRb::Dependencies::RULES`.
- Empty `mj-image` and `mj-font` are accepted, matching the v5 validator.
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
- the complete body returned by `Components::Body`, including preview and accessible article

Selector-based HTML attributes are applied to the real body before skeleton
assembly. Inline CSS runs on the complete document. `Formatter` protects raw
regions and conditionals without reserializing the entire HTML document.

This is an important architectural detail: the project is not purely
string-based. It renders to HTML as a string, then reparses that HTML for
selector-based mutations.

## Components of Note

Some behaviors are important enough to call out because they shape the rest of
the architecture:

- `Body`
  - Owns `<body>`, its id/class/background, preview and accessible article; sets container width.
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
  - Defers selector-based mutations until body rendering is complete.
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

Component fixtures coexist with pinned v5 differential contracts in
`test/reference`. CI compares these contracts against `mjml@5.4.1`, installed
only for development. See `docs/PARITY_AUDIT.md` for the exact coverage and limits.

## Extension Workflow

To add a new component safely, the usual steps are:

1. Create a new class under `lib/mjml-rb/components/` that inherits from
   `MjmlRb::Components::Base`.
2. Declare `TAGS` and attribute metadata.
3. Implement `render`.
4. Implement `handle_head` and/or `head_style` if the component affects head
   processing.
5. Register through `MjmlRb.register_component`, including custom ending tags and dependencies.
6. Add parent/child rules to `Dependencies::RULES`.
7. Add tests that cover rendering and validation behavior.

If a tag is allowed by dependency rules but has no renderer implementation, it
may validate successfully but still not produce correct output. That risk now
applies mainly to future dependency-only tags rather than the current carousel
implementation.

## Shared metadata and layout

`ComponentRegistry` supplies the classes, dependency rules and ending-tag set to
parser, validator and renderer. Its revision invalidates renderer caches when
components are registered or reset; collisions with another class are rejected.
A compiler creates per-call parser and renderer instances, so concurrent
compilations do not share include diagnostics or rendering context.

`ColumnGutter` calculates width reduction and edge-aware desktop/mobile/Outlook
padding from the section or group context. The responsive rule registry stores
width or padding rules; a layout value is shared by a column and its Outlook cell.

## Current limitations

See [the compatibility audit](PARITY_AUDIT.md) for the tested MJML 5.4.1 scope,
strict structural XML parsing, custom inliner/formatter differences, unsupported
options and watch limitations. Node is used only by the development oracle.
