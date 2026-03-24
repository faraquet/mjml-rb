# mjml-rb Usage Guide

A pure-Ruby MJML compiler — no Node.js required. Compiles [MJML v4](https://mjml.io/) markup into responsive HTML email.

- **Ruby**: >= 3.0
- **Dependencies**: css_parser (>= 1.17), nokogiri (>= 1.13)
- **License**: MIT

---

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Ruby API](#ruby-api)
  - [MjmlRb.mjml2html](#mjmlrbmjml2html)
  - [Compiler](#compiler)
  - [Result Object](#result-object)
  - [Compiler Options](#compiler-options)
- [CLI](#cli)
  - [Flags](#flags)
  - [Examples](#cli-examples)
  - [Config File (.mjmlrc)](#config-file-mjmlrc)
- [Rails Integration](#rails-integration)
- [Components Reference](#components-reference)
  - [Document Structure](#document-structure)
  - [Layout Components](#layout-components)
  - [Content Components](#content-components)
  - [Head-only Components](#head-only-components)
- [Component Hierarchy](#component-hierarchy)
- [Includes (mj-include)](#includes-mj-include)
- [Validation](#validation)
- [Custom Components](#custom-components)

---

## Installation

Add to your Gemfile:

```ruby
gem "mjml-rb"
```

Or install directly:

```bash
gem install mjml-rb
```

---

## Quick Start

```ruby
require "mjml-rb"

result = MjmlRb.mjml2html(<<~MJML)
  <mjml>
    <mj-body>
      <mj-section>
        <mj-column>
          <mj-text>Hello World!</mj-text>
        </mj-column>
      </mj-section>
    </mj-body>
  </mjml>
MJML

puts result[:html]     # => "<!doctype html>..."
puts result[:errors]   # => []
```

---

## Ruby API

### MjmlRb.mjml2html

```ruby
MjmlRb.mjml2html(mjml_string, options = {}) → Hash
```

Compiles an MJML string and returns a hash:

```ruby
{
  html:     "<!doctype html>...",  # compiled HTML (empty string on fatal error)
  errors:   [],                     # array of error hashes
  warnings: []                      # array of warning hashes
}
```

`MjmlRb.to_html` is an alias for `MjmlRb.mjml2html`.

### Compiler

For repeated compilations, instantiate a compiler to reuse configuration:

```ruby
compiler = MjmlRb::Compiler.new(
  validation_level: "strict",
  beautify: true,
  keep_comments: false
)

result = compiler.compile(mjml_string)
result = compiler.compile(another_mjml_string)  # same options
```

You can also pass per-call overrides:

```ruby
result = compiler.compile(mjml_string, minify: true)
```

### Result Object

`Compiler#compile` returns a `MjmlRb::Result`:

| Method | Return | Description |
|--------|--------|-------------|
| `html` | `String` | Compiled HTML output (empty on fatal error) |
| `errors` | `Array[Hash]` | Validation errors and parse failures |
| `warnings` | `Array[Hash]` | Non-blocking issues (soft mode include failures, etc.) |
| `success?` | `Boolean` | `true` if `errors` is empty |
| `to_h` | `Hash` | `{html:, errors:, warnings:}` |

Each error/warning hash contains:

```ruby
{
  line:              Integer or nil,  # source line number
  message:           String,          # human-readable message
  tag_name:          String or nil,   # the MJML tag involved
  formatted_message: String           # display-ready message
}
```

### Compiler Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `validation_level` | `String` | `"soft"` | `"soft"`, `"strict"`, or `"skip"` |
| `beautify` | `Boolean` | `false` | Pretty-print output HTML |
| `minify` | `Boolean` | `false` | Minify output HTML |
| `keep_comments` | `Boolean` | `true` | Preserve HTML comments in output |
| `ignore_includes` | `Boolean` | `false` | Skip `mj-include` processing |
| `printer_support` | `Boolean` | `false` | Add `@media print` CSS rules |
| `preprocessors` | `Array` | `[]` | Callables applied to MJML before parsing |
| `file_path` | `String` | `"."` | Base directory for resolving includes |
| `actual_path` | `String` | `"."` | Actual file path for relative includes |
| `lang` | `String` | `"und"` | HTML `lang` attribute |
| `dir` | `String` | `"auto"` | HTML `dir` attribute |
| `fonts` | `Hash` | *(built-in)* | `{"Font Name" => "URL"}` for Google Fonts |

**Validation levels:**

| Level | Behavior |
|-------|----------|
| `"soft"` | Validation issues reported as warnings; compilation proceeds |
| `"strict"` | Validation issues reported as errors; compilation halts if any found |
| `"skip"` | No validation at all |

**Preprocessors** are callables (lambdas, procs) that transform the raw MJML string before parsing:

```ruby
upcase_tags = ->(mjml) { mjml.gsub(/mj-text/, "mj-text") }
compiler = MjmlRb::Compiler.new(preprocessors: [upcase_tags])
```

---

## CLI

The gem installs a `mjml` binary:

```bash
mjml [options] [files]
```

### Flags

| Flag | Alias | Argument | Description |
|------|-------|----------|-------------|
| `-r` | `--read` | `FILES` | Compile MJML file(s) (comma-separated or glob) |
| `-v` | `--validate` | `FILES` | Validate MJML file(s) with strict validation |
| `-w` | `--watch` | `FILES` | Watch file(s) and recompile on change |
| `-i` | `--stdin` | — | Read MJML from stdin |
| `-s` | `--stdout` | — | Write HTML to stdout (default output) |
| `-o` | `--output` | `PATH` | Write HTML to file or directory |
| `-c` | `--config` | `KEY=VALUE` | Set compiler option (repeatable) |
| | `--noStdoutFileComment` | — | Omit `<!-- FILE: ... -->` header on stdout |
| `-V` | `--version` | — | Print version and exit |
| `-h` | `--help` | — | Print help and exit |

Inline config is also supported: `--config.beautify=true`

### CLI Examples

```bash
# Compile a file to stdout
mjml -r email.mjml -s

# Compile to a file
mjml -r email.mjml -o email.html

# Compile all .mjml files in a directory
mjml -r "templates/*.mjml" -o output/

# Validate without compiling
mjml -v email.mjml

# Read from stdin, minify
mjml -i -s -c minify=true < email.mjml

# Watch mode
mjml -w email.mjml -o email.html
```

### Config File (.mjmlrc)

Place a `.mjmlrc` file (JSON) in your project root:

```json
{
  "packages": [
    "./lib/my_custom_component.rb"
  ],
  "options": {
    "beautify": true,
    "validation_level": "soft"
  }
}
```

| Key | Type | Description |
|-----|------|-------------|
| `packages` | `Array[String]` | Ruby files to `require` (for custom components) |
| `options` | `Hash` | Compiler options (same as Ruby API) |

---

## Rails Integration

mjml-rb auto-registers a `.mjml` template handler when Rails is loaded.

### Setup

```ruby
# Gemfile
gem "mjml-rb"
```

No additional configuration needed for raw XML MJML templates.

### Mailer Template

```erb
<!-- app/views/user_mailer/welcome.html.mjml -->
<mjml>
  <mj-body>
    <mj-section>
      <mj-column>
        <mj-text>Welcome, <%= @user.name %>!</mj-text>
        <mj-button href="<%= dashboard_url %>">Go to Dashboard</mj-button>
      </mj-column>
    </mj-section>
  </mj-body>
</mjml>
```

### Configuration

```ruby
# config/initializers/mjml.rb

# Set compiler options for Rails (default: strict validation)
MjmlRb.rails_compiler_options = {
  validation_level: "strict",
  keep_comments: false
}

# For Slim/Haml templates instead of raw XML:
MjmlRb.rails_template_language = :slim   # or :haml
```

Or via Railtie config:

```ruby
# config/application.rb
config.mjml_rb.compiler_options = { validation_level: "strict" }
config.mjml_rb.rails_template_language = :slim
```

---

## Components Reference

### Document Structure

#### mj-body

Top-level content container. Required.

```xml
<mjml>
  <mj-body background-color="#f4f4f4" width="600px">
    ...
  </mj-body>
</mjml>
```

| Attribute | Type | Default |
|-----------|------|---------|
| `background-color` | color | — |
| `width` | px | `600px` |

---

### Layout Components

#### mj-section

Horizontal layout container. Direct child of `mj-body`.

```xml
<mj-section background-color="#ffffff" padding="20px 0">
  <mj-column>...</mj-column>
</mj-section>
```

| Attribute | Type | Default |
|-----------|------|---------|
| `background-color` | color | — |
| `background-url` | string | — |
| `background-repeat` | `repeat` / `no-repeat` | `repeat` |
| `background-size` | string | `auto` |
| `background-position` | string | `top center` |
| `background-position-x` | string | — |
| `background-position-y` | string | — |
| `border` | string | — |
| `border-bottom` | string | — |
| `border-left` | string | — |
| `border-right` | string | — |
| `border-top` | string | — |
| `border-radius` | string | — |
| `direction` | `ltr` / `rtl` | `ltr` |
| `full-width` | `full-width` / *(empty)* | — |
| `padding` | px/% (1-4 values) | `20px 0` |
| `padding-top` | px/% | — |
| `padding-right` | px/% | — |
| `padding-bottom` | px/% | — |
| `padding-left` | px/% | — |
| `text-align` | `left` / `center` / `right` | `center` |
| `text-padding` | px/% (1-4 values) | `4px 4px 4px 0` |

**Allowed children**: `mj-column`, `mj-group`, `mj-raw`

#### mj-wrapper

Like `mj-section` but wraps multiple sections. Supports all section attributes plus:

| Attribute | Type | Default |
|-----------|------|---------|
| `gap` | px | — |

**Allowed children**: `mj-hero`, `mj-raw`, `mj-section`

#### mj-column

Responsive column within a section. Width auto-calculated when omitted.

```xml
<mj-column width="50%" background-color="#f0f0f0">
  <mj-text>Content</mj-text>
</mj-column>
```

| Attribute | Type | Default |
|-----------|------|---------|
| `background-color` | color | — |
| `border` | string | — |
| `border-bottom` | string | — |
| `border-left` | string | — |
| `border-right` | string | — |
| `border-top` | string | — |
| `border-radius` | px/% (1-4 values) | — |
| `direction` | `ltr` / `rtl` | `ltr` |
| `inner-background-color` | color | — |
| `inner-border` | string | — |
| `inner-border-bottom` | string | — |
| `inner-border-left` | string | — |
| `inner-border-right` | string | — |
| `inner-border-top` | string | — |
| `inner-border-radius` | px/% (1-4 values) | — |
| `padding` | px/% (1-4 values) | — |
| `padding-top` | px/% | — |
| `padding-right` | px/% | — |
| `padding-bottom` | px/% | — |
| `padding-left` | px/% | — |
| `vertical-align` | `top` / `middle` / `bottom` | `top` |
| `width` | px/% | *(auto)* |

**Allowed children**: `mj-accordion`, `mj-button`, `mj-carousel`, `mj-divider`, `mj-image`, `mj-raw`, `mj-social`, `mj-spacer`, `mj-table`, `mj-text`, `mj-navbar`

#### mj-group

Groups columns to prevent wrapping on mobile.

| Attribute | Type | Default |
|-----------|------|---------|
| `background-color` | color | — |
| `direction` | `ltr` / `rtl` | `ltr` |
| `vertical-align` | `top` / `middle` / `bottom` | — |
| `width` | px/% | — |

**Allowed children**: `mj-column`, `mj-raw`

#### mj-hero

Hero banner with background image overlay.

```xml
<mj-hero mode="fluid-height" background-url="https://example.com/bg.jpg">
  <mj-text>Overlay Text</mj-text>
</mj-hero>
```

| Attribute | Type | Default |
|-----------|------|---------|
| `mode` | `fixed-height` / `fluid-height` | `fixed-height` |
| `height` | px/% | `0px` |
| `background-url` | string | — |
| `background-width` | px/% | — |
| `background-height` | px/% | — |
| `background-position` | string | `center center` |
| `background-color` | color | `#ffffff` |
| `border-radius` | string | — |
| `container-background-color` | color | — |
| `inner-background-color` | color | — |
| `inner-padding` | px/% (1-4 values) | — |
| `inner-padding-top` | px/% | — |
| `inner-padding-left` | px/% | — |
| `inner-padding-right` | px/% | — |
| `inner-padding-bottom` | px/% | — |
| `padding` | px/% (1-4 values) | `0px` |
| `padding-top` | px/% | — |
| `padding-right` | px/% | — |
| `padding-bottom` | px/% | — |
| `padding-left` | px/% | — |
| `vertical-align` | `top` / `middle` / `bottom` | `top` |

**Allowed children**: `mj-accordion`, `mj-button`, `mj-carousel`, `mj-divider`, `mj-image`, `mj-social`, `mj-spacer`, `mj-table`, `mj-text`, `mj-navbar`, `mj-raw`

---

### Content Components

#### mj-text

Block of text/HTML content.

```xml
<mj-text font-size="16px" color="#333333" align="center">
  <p>Hello <strong>World</strong>!</p>
</mj-text>
```

| Attribute | Type | Default |
|-----------|------|---------|
| `align` | `left` / `right` / `center` / `justify` | `left` |
| `background-color` | color | — |
| `color` | color | `#000000` |
| `container-background-color` | color | — |
| `font-family` | string | `Ubuntu, Helvetica, Arial, sans-serif` |
| `font-size` | px | `13px` |
| `font-style` | string | — |
| `font-weight` | string | — |
| `height` | px/% | — |
| `letter-spacing` | px/em (negative ok) | — |
| `line-height` | px/%/unitless | `1` |
| `padding` | px/% (1-4 values) | `10px 25px` |
| `padding-top` | px/% | — |
| `padding-right` | px/% | — |
| `padding-bottom` | px/% | — |
| `padding-left` | px/% | — |
| `text-decoration` | string | — |
| `text-transform` | string | — |
| `vertical-align` | `top` / `middle` / `bottom` | — |

#### mj-image

Responsive image with optional link.

```xml
<mj-image src="https://example.com/image.jpg"
           alt="Description"
           href="https://example.com"
           width="300px" />
```

| Attribute | Type | Default |
|-----------|------|---------|
| `src` | string | — (**required**) |
| `alt` | string | `""` |
| `href` | string | — |
| `name` | string | — |
| `title` | string | — |
| `rel` | string | — |
| `srcset` | string | — |
| `sizes` | string | — |
| `align` | `left` / `center` / `right` | `center` |
| `border` | string | `0` |
| `border-bottom` | string | — |
| `border-left` | string | — |
| `border-right` | string | — |
| `border-top` | string | — |
| `border-radius` | px/% (1-4 values) | — |
| `container-background-color` | color | — |
| `fluid-on-mobile` | boolean | — |
| `full-width` | `full-width` | — |
| `padding` | px/% (1-4 values) | `10px 25px` |
| `padding-top` | px/% | — |
| `padding-right` | px/% | — |
| `padding-bottom` | px/% | — |
| `padding-left` | px/% | — |
| `target` | string | `_blank` |
| `width` | px | — |
| `height` | px/auto | `auto` |
| `max-height` | px/% | — |
| `font-size` | px | `13px` |
| `usemap` | string | — |

#### mj-button

Call-to-action button. Inner HTML is preserved.

```xml
<mj-button href="https://example.com"
            background-color="#ff6600"
            color="#ffffff"
            border-radius="8px">
  Sign Up Now
</mj-button>
```

| Attribute | Type | Default |
|-----------|------|---------|
| `href` | string | — |
| `name` | string | — |
| `title` | string | — |
| `rel` | string | — |
| `align` | `left` / `center` / `right` | `center` |
| `background-color` | color | `#414141` |
| `border` | string | `none` |
| `border-bottom` | string | — |
| `border-left` | string | — |
| `border-right` | string | — |
| `border-top` | string | — |
| `border-radius` | string | `3px` |
| `color` | color | `#ffffff` |
| `container-background-color` | color | — |
| `font-family` | string | `Ubuntu, Helvetica, Arial, sans-serif` |
| `font-size` | px | `13px` |
| `font-style` | string | — |
| `font-weight` | string | `normal` |
| `height` | px/% | — |
| `inner-padding` | px/% (1-4 values) | `10px 25px` |
| `letter-spacing` | px/em (negative ok) | — |
| `line-height` | px/%/unitless | `120%` |
| `padding` | px/% (1-4 values) | `10px 25px` |
| `padding-top` | px/% | — |
| `padding-right` | px/% | — |
| `padding-bottom` | px/% | — |
| `padding-left` | px/% | — |
| `target` | string | `_blank` |
| `text-decoration` | string | `none` |
| `text-transform` | string | `none` |
| `text-align` | `left` / `right` / `center` | — |
| `vertical-align` | `top` / `middle` / `bottom` | `middle` |
| `width` | px/% | — |

When `href` is omitted, renders a `<p>` tag instead of `<a>`.

#### mj-divider

Horizontal rule/divider.

```xml
<mj-divider border-color="#cccccc" border-width="1px" border-style="dashed" />
```

| Attribute | Type | Default |
|-----------|------|---------|
| `align` | `left` / `center` / `right` | `center` |
| `border-color` | color | `#000000` |
| `border-style` | string | `solid` |
| `border-width` | px | `4px` |
| `container-background-color` | color | — |
| `padding` | px/% (1-4 values) | `10px 25px` |
| `padding-top` | px/% | — |
| `padding-right` | px/% | — |
| `padding-bottom` | px/% | — |
| `padding-left` | px/% | — |
| `width` | px/% | `100%` |

#### mj-spacer

Vertical spacing element.

```xml
<mj-spacer height="40px" />
```

| Attribute | Type | Default |
|-----------|------|---------|
| `height` | px/% | `20px` |
| `border` | string | — |
| `border-bottom` | string | — |
| `border-left` | string | — |
| `border-right` | string | — |
| `border-top` | string | — |
| `container-background-color` | color | — |
| `padding` | px/% (1-4 values) | — |
| `padding-top` | px/% | — |
| `padding-right` | px/% | — |
| `padding-bottom` | px/% | — |
| `padding-left` | px/% | — |

#### mj-table

HTML table with email-safe defaults. Inner HTML is preserved.

```xml
<mj-table>
  <tr>
    <th>Name</th>
    <th>Price</th>
  </tr>
  <tr>
    <td>Widget</td>
    <td>$9.99</td>
  </tr>
</mj-table>
```

| Attribute | Type | Default |
|-----------|------|---------|
| `align` | `left` / `right` / `center` | `left` |
| `border` | string | `none` |
| `cellpadding` | integer | `0` |
| `cellspacing` | integer | `0` |
| `color` | color | `#000000` |
| `container-background-color` | color | — |
| `font-family` | string | `Ubuntu, Helvetica, Arial, sans-serif` |
| `font-size` | px | `13px` |
| `font-weight` | string | — |
| `line-height` | px/%/unitless | `22px` |
| `padding` | px/% (1-4 values) | `10px 25px` |
| `padding-top` | px/% | — |
| `padding-right` | px/% | — |
| `padding-bottom` | px/% | — |
| `padding-left` | px/% | — |
| `role` | `none` / `presentation` | — |
| `table-layout` | `auto` / `fixed` / `initial` / `inherit` | `auto` |
| `vertical-align` | `top` / `middle` / `bottom` | — |
| `width` | px/%/auto | `100%` |

#### mj-raw

Insert raw HTML directly. Not processed by the MJML engine.

```xml
<mj-raw>
  <div class="custom">Any HTML here</div>
</mj-raw>
```

| Attribute | Type | Default |
|-----------|------|---------|
| `position` | `file-start` | — |

Use `position="file-start"` to insert content before the `<!doctype>`.

#### mj-social

Social media icon links.

```xml
<mj-social font-size="14px" icon-size="24px" mode="horizontal">
  <mj-social-element name="facebook" href="https://facebook.com/page">
    Facebook
  </mj-social-element>
  <mj-social-element name="twitter" href="https://twitter.com/handle">
    Twitter
  </mj-social-element>
</mj-social>
```

**mj-social attributes:**

| Attribute | Type | Default |
|-----------|------|---------|
| `align` | `left` / `center` / `right` | `center` |
| `border-radius` | px/% | `3px` |
| `color` | color | `#333333` |
| `container-background-color` | color | — |
| `font-family` | string | `Ubuntu, Helvetica, Arial, sans-serif` |
| `font-size` | px | `13px` |
| `font-style` | string | — |
| `font-weight` | string | — |
| `icon-size` | px/% | `20px` |
| `icon-height` | px/% | — |
| `icon-padding` | px/% (1-4 values) | — |
| `inner-padding` | px/% (1-4 values) | — |
| `line-height` | px/%/unitless | `22px` |
| `mode` | `horizontal` / `vertical` | `horizontal` |
| `padding` | px/% (1-4 values) | `10px 25px` |
| `padding-top` | px/% | — |
| `padding-right` | px/% | — |
| `padding-bottom` | px/% | — |
| `padding-left` | px/% | — |
| `table-layout` | `auto` / `fixed` | — |
| `text-padding` | px/% (1-4 values) | — |
| `text-decoration` | string | `none` |
| `vertical-align` | `top` / `middle` / `bottom` | — |

**mj-social-element attributes:**

| Attribute | Type | Default |
|-----------|------|---------|
| `name` | string | — |
| `href` | string | — |
| `src` | string | — |
| `srcset` | string | — |
| `sizes` | string | — |
| `alt` | string | `""` |
| `title` | string | — |
| `target` | string | `_blank` |
| `rel` | string | — |
| `align` | `left` / `center` / `right` | `left` |
| `icon-position` | `left` / `right` | `left` |
| `background-color` | color | — |
| `border-radius` | px | `3px` |
| `color` | color | `#000` |
| `font-family` | string | `Ubuntu, Helvetica, Arial, sans-serif` |
| `font-size` | px | `13px` |
| `font-style` | string | — |
| `font-weight` | string | — |
| `icon-size` | px/% | — |
| `icon-height` | px/% | — |
| `icon-padding` | px/% (1-4 values) | — |
| `line-height` | px/%/unitless | `1` |
| `padding` | px/% (1-4 values) | `4px` |
| `padding-top` | px/% | — |
| `padding-right` | px/% | — |
| `padding-bottom` | px/% | — |
| `padding-left` | px/% | — |
| `text-padding` | px/% (1-4 values) | `4px 4px 4px 0` |
| `text-decoration` | string | `none` |
| `vertical-align` | `top` / `middle` / `bottom` | `middle` |

**Built-in network names**: `facebook`, `twitter`, `x`, `google`, `pinterest`, `linkedin`, `instagram`, `web`, `snapchat`, `youtube`, `tumblr`, `github`, `xing`, `vimeo`, `medium`, `soundcloud`, `dribbble`. Each also has a `-noshare` variant (e.g. `facebook-noshare`).

#### mj-navbar

Navigation bar with optional hamburger menu for mobile.

```xml
<mj-navbar hamburger="hamburger">
  <mj-navbar-link href="/home">Home</mj-navbar-link>
  <mj-navbar-link href="/about">About</mj-navbar-link>
</mj-navbar>
```

**mj-navbar attributes:**

| Attribute | Type | Default |
|-----------|------|---------|
| `align` | `left` / `center` / `right` | — |
| `base-url` | string | — |
| `hamburger` | `hamburger` | — |
| `ico-align` | `left` / `center` / `right` | — |
| `ico-open` | string | — |
| `ico-close` | string | — |
| `ico-color` | color | — |
| `ico-font-size` | px/% | — |
| `ico-font-family` | string | — |
| `ico-text-transform` | string | — |
| `ico-padding` | px/% (1-4 values) | — |
| `ico-padding-top` | px/% | — |
| `ico-padding-right` | px/% | — |
| `ico-padding-bottom` | px/% | — |
| `ico-padding-left` | px/% | — |
| `ico-text-decoration` | string | — |
| `ico-line-height` | px/%/unitless | — |
| `padding` | px/% (1-4 values) | — |
| `padding-top` | px/% | — |
| `padding-right` | px/% | — |
| `padding-bottom` | px/% | — |
| `padding-left` | px/% | — |

**mj-navbar-link attributes:**

| Attribute | Type | Default |
|-----------|------|---------|
| `href` | string | — |
| `name` | string | — |
| `target` | string | — |
| `rel` | string | — |
| `color` | color | — |
| `font-family` | string | — |
| `font-size` | px | — |
| `font-style` | string | — |
| `font-weight` | string | — |
| `letter-spacing` | px/em (negative ok) | — |
| `line-height` | px/%/unitless | — |
| `padding` | px/% (1-4 values) | — |
| `padding-top` | px/% | — |
| `padding-right` | px/% | — |
| `padding-bottom` | px/% | — |
| `padding-left` | px/% | — |
| `text-decoration` | string | — |
| `text-transform` | string | — |

#### mj-carousel

Image carousel with thumbnails.

```xml
<mj-carousel thumbnails="visible">
  <mj-carousel-image src="https://example.com/1.jpg" />
  <mj-carousel-image src="https://example.com/2.jpg" />
</mj-carousel>
```

**mj-carousel attributes:**

| Attribute | Type | Default |
|-----------|------|---------|
| `align` | `left` / `center` / `right` | `center` |
| `border-radius` | px/% (1-4 values) | `6px` |
| `container-background-color` | color | — |
| `icon-width` | px/% | `44px` |
| `left-icon` | string (URL) | *(imgur default)* |
| `right-icon` | string (URL) | *(imgur default)* |
| `thumbnails` | `visible` / `hidden` / `supported` | `visible` |
| `tb-border` | string | `2px solid transparent` |
| `tb-border-radius` | px/% | `6px` |
| `tb-hover-border-color` | color | `#fead0d` |
| `tb-selected-border-color` | color | `#ccc` |
| `tb-width` | px/% | — |
| `padding` | px/% (1-4 values) | — |
| `padding-top` | px/% | — |
| `padding-right` | px/% | — |
| `padding-bottom` | px/% | — |
| `padding-left` | px/% | — |

**mj-carousel-image attributes:**

| Attribute | Type | Default |
|-----------|------|---------|
| `src` | string | — |
| `alt` | string | `""` |
| `href` | string | — |
| `rel` | string | — |
| `target` | string | `_blank` |
| `title` | string | — |
| `thumbnails-src` | string | — |
| `border-radius` | px/% (1-4 values) | — |
| `tb-border` | string | — |
| `tb-border-radius` | px/% (1-4 values) | — |

#### mj-accordion

Expandable/collapsible sections.

```xml
<mj-accordion border="1px solid #ddd">
  <mj-accordion-element>
    <mj-accordion-title>Section 1</mj-accordion-title>
    <mj-accordion-text>Content for section 1.</mj-accordion-text>
  </mj-accordion-element>
</mj-accordion>
```

**mj-accordion attributes:**

| Attribute | Type | Default |
|-----------|------|---------|
| `border` | string | `2px solid black` |
| `container-background-color` | color | — |
| `font-family` | string | `Ubuntu, Helvetica, Arial, sans-serif` |
| `icon-align` | `top` / `middle` / `bottom` | `middle` |
| `icon-width` | px/% | `32px` |
| `icon-height` | px/% | `32px` |
| `icon-wrapped-url` | string | *(default +)* |
| `icon-wrapped-alt` | string | `+` |
| `icon-unwrapped-url` | string | *(default -)* |
| `icon-unwrapped-alt` | string | `-` |
| `icon-position` | `left` / `right` | `right` |
| `padding` | px/% (1-4 values) | `10px 25px` |
| `padding-top` | px/% | — |
| `padding-right` | px/% | — |
| `padding-bottom` | px/% | — |
| `padding-left` | px/% | — |

---

### Head-only Components

These go inside `<mj-head>` and configure the document.

#### mj-breakpoint

Set the mobile breakpoint width.

```xml
<mj-head>
  <mj-breakpoint width="600px" />
</mj-head>
```

| Attribute | Type | Default |
|-----------|------|---------|
| `width` | px | `480px` |

#### mj-title

Set the HTML `<title>` tag.

```xml
<mj-title>My Email Subject</mj-title>
```

#### mj-preview

Set hidden preview text (shown in inbox list).

```xml
<mj-preview>This is the preview text shown in email clients.</mj-preview>
```

#### mj-font

Register a Google Font for use in the email.

```xml
<mj-font name="Montserrat" href="https://fonts.googleapis.com/css2?family=Montserrat:wght@400;700" />
```

| Attribute | Type | Default |
|-----------|------|---------|
| `name` | string | — (**required**) |
| `href` | string | — (**required**) |

**Built-in fonts** (no `mj-font` needed): Open Sans, Droid Sans, Lato, Roboto, Ubuntu.

#### mj-style

Inject custom CSS into the `<head>`.

```xml
<mj-style>
  .custom-class { color: red; }
</mj-style>

<!-- Inline styles into element style attributes: -->
<mj-style inline="inline">
  .btn a { color: #00ada5; }
</mj-style>
```

| Attribute | Type | Default |
|-----------|------|---------|
| `inline` | `inline` | — |

#### mj-attributes

Set default attributes for components globally or by class.

```xml
<mj-head>
  <mj-attributes>
    <mj-all font-family="Helvetica" />
    <mj-text font-size="16px" color="#333" />
    <mj-class name="headline" font-size="24px" font-weight="bold" />
  </mj-attributes>
</mj-head>
```

Use `mj-class="headline"` on any component to apply class defaults.

#### mj-html-attributes

Add HTML attributes to rendered elements via CSS selectors.

```xml
<mj-head>
  <mj-html-attributes>
    <mj-selector path=".custom-table table">
      <mj-html-attribute name="role">presentation</mj-html-attribute>
    </mj-selector>
  </mj-html-attributes>
</mj-head>
```

---

## Component Hierarchy

```
mjml
├── mj-head
│   ├── mj-attributes
│   ├── mj-breakpoint
│   ├── mj-font
│   ├── mj-html-attributes
│   ├── mj-preview
│   ├── mj-style
│   ├── mj-title
│   └── mj-raw
└── mj-body
    ├── mj-section
    │   ├── mj-column
    │   │   ├── mj-accordion
    │   │   ├── mj-button
    │   │   ├── mj-carousel
    │   │   ├── mj-divider
    │   │   ├── mj-image
    │   │   ├── mj-navbar
    │   │   ├── mj-raw
    │   │   ├── mj-social
    │   │   ├── mj-spacer
    │   │   ├── mj-table
    │   │   └── mj-text
    │   ├── mj-group
    │   │   └── mj-column
    │   └── mj-raw
    ├── mj-wrapper
    │   ├── mj-section
    │   ├── mj-hero
    │   └── mj-raw
    ├── mj-hero
    │   └── (same children as mj-column)
    └── mj-raw
```

**Global attributes** available on all components: `css-class`, `mj-class`.

---

## Includes (mj-include)

Include external MJML, HTML, or CSS files:

```xml
<!-- Include MJML content (parsed and merged) -->
<mj-include path="./partials/header.mjml" />

<!-- Include raw HTML (wrapped in mj-raw) -->
<mj-include path="./snippets/tracking.html" type="html" />

<!-- Include CSS (added to <head>) -->
<mj-include path="./styles/theme.css" type="css" />

<!-- Include CSS and inline it into style attributes -->
<mj-include path="./styles/inline.css" type="css" css-inline="inline" />
```

| Attribute | Type | Description |
|-----------|------|-------------|
| `path` | string | File path to include (**required**) |
| `type` | `html` / `css` | Include mode (default: MJML content) |
| `css-inline` | `inline` | Inline CSS into style attributes (only with `type="css"`) |

- Paths are resolved relative to the including file
- Circular includes are detected and raise an error
- Missing files produce warnings (soft mode) or errors (strict mode)
- Nested includes are fully supported

---

## Validation

The validator checks:

1. **Root element** must be `<mjml>`
2. **Required children** — `<mj-body>` must exist
3. **Known tags** — only registered MJML components allowed
4. **Hierarchy** — children must be valid for their parent
5. **Required attributes** — e.g. `src` on `mj-image`, `name`+`href` on `mj-font`
6. **Supported attributes** — unknown attributes are flagged
7. **Attribute types** — values validated against type definitions

**Attribute type definitions:**

| Type | Example Values |
|------|---------------|
| `string` | Any string |
| `boolean` | `"true"`, `"false"` |
| `integer` | `"42"` |
| `color` | `#fff`, `#ff0000`, `rgb(0,0,0)`, `hsl(0,0%,0%)`, `red` |
| `enum(a,b,c)` | One of the listed values |
| `unit(px)` | `"13px"` |
| `unit(px,%)` | `"13px"`, `"50%"` |
| `unit(px,%){1,4}` | `"10px"`, `"10px 20px"`, `"10px 20px 30px 40px"` |
| `unitWithNegative(px,em)` | `"-1px"`, `"0.5em"` |

---

## Custom Components

### Define a Component

```ruby
class MjBadge < MjmlRb::Components::Base
  TAGS = ["mj-badge"].freeze

  ALLOWED_ATTRIBUTES = {
    "text" => "string",
    "background-color" => "color",
    "color" => "color",
    "border-radius" => "unit(px)",
    "padding" => "unit(px,%){1,4}"
  }.freeze

  DEFAULT_ATTRIBUTES = {
    "background-color" => "#e74c3c",
    "color" => "#ffffff",
    "border-radius" => "4px",
    "padding" => "4px 8px"
  }.freeze

  def render(tag_name:, node:, context:, attrs:, parent:)
    a = DEFAULT_ATTRIBUTES.merge(attrs)
    style = style_join(
      "background-color" => a["background-color"],
      "color" => a["color"],
      "border-radius" => a["border-radius"],
      "padding" => a["padding"],
      "display" => "inline-block",
      "font-size" => "12px"
    )
    text = a["text"] || raw_inner(node)
    %(<tr><td><span style="#{style}">#{escape_html(text)}</span></td></tr>)
  end
end
```

### Register

```ruby
MjmlRb.register_component(
  MjBadge,
  dependencies: { "mj-column" => ["mj-badge"] },
  ending_tags: []  # set to ["mj-badge"] if inner HTML should be preserved raw
)
```

### Use

```xml
<mjml>
  <mj-body>
    <mj-section>
      <mj-column>
        <mj-badge text="NEW" background-color="#27ae60" />
      </mj-column>
    </mj-section>
  </mj-body>
</mjml>
```

### Available Helper Methods

| Method | Description |
|--------|-------------|
| `render_node(node, context, parent:)` | Render a single child node |
| `render_children(node, context, parent:)` | Render all children |
| `resolved_attributes(node, context)` | Get merged attributes (defaults + classes + inline) |
| `raw_inner(node)` | Get raw inner HTML (for ending-tag components) |
| `html_inner(node)` | Get HTML-escaped inner content |
| `style_join(hash)` | Build CSS style string from hash (skips nil values) |
| `escape_html(value)` | HTML-escape a string |
| `escape_attr(value)` | Attribute-escape a string |
| `html_attrs(hash)` | Build HTML attribute string (skips nil values) |
| `shorthand_value(parts, side)` | Parse CSS shorthand (from CssHelpers) |
| `parse_border_width(str)` | Extract border width in px (from CssHelpers) |

### Reset Custom Components

```ruby
MjmlRb.component_registry.reset!
```
