require "set"

module MjmlRb
  module Dependencies
    # Components whose content is treated as raw HTML in NPM (endingTag = true).
    # The parser preserves their inner markup as-is; the validator skips child
    # element checks because REXML structurally parses what NPM treats as text.
    ENDING_TAGS = Set.new(%w[
      mj-accordion-text
      mj-accordion-title
      mj-button
      mj-carousel-image
      mj-navbar-link
      mj-raw
      mj-table
      mj-text
    ]).freeze

    RULES = {
      "mjml" => ["mj-body", "mj-head", "mj-raw"],
      "mj-accordion" => ["mj-accordion-element", "mj-raw"],
      "mj-accordion-element" => ["mj-accordion-title", "mj-accordion-text", "mj-raw"],
      "mj-accordion-title" => [],
      "mj-accordion-text" => [],
      "mj-attributes" => [/.*/],
      "mj-body" => ["mj-raw", "mj-section", "mj-wrapper", "mj-hero"],
      "mj-button" => [],
      "mj-carousel" => ["mj-carousel-image"],
      "mj-carousel-image" => [],
      "mj-column" => [
        "mj-accordion",
        "mj-button",
        "mj-carousel",
        "mj-divider",
        "mj-image",
        "mj-raw",
        "mj-social",
        "mj-spacer",
        "mj-table",
        "mj-text",
        "mj-navbar"
      ],
      "mj-html-attribute" => [],
      "mj-html-attributes" => ["mj-selector"],
      "mj-divider" => [],
      "mj-group" => ["mj-column", "mj-raw"],
      "mj-head" => [
        "mj-attributes",
        "mj-breakpoint",
        "mj-html-attributes",
        "mj-font",
        "mj-preview",
        "mj-style",
        "mj-title",
        "mj-raw"
      ],
      "mj-hero" => [
        "mj-accordion",
        "mj-button",
        "mj-carousel",
        "mj-divider",
        "mj-image",
        "mj-social",
        "mj-spacer",
        "mj-table",
        "mj-text",
        "mj-navbar",
        "mj-raw"
      ],
      "mj-image" => [],
      "mj-navbar" => ["mj-navbar-link", "mj-raw"],
      "mj-raw" => [],
      "mj-section" => ["mj-column", "mj-group", "mj-raw"],
      "mj-selector" => ["mj-html-attribute"],
      "mj-social" => ["mj-social-element", "mj-raw"],
      "mj-social-element" => [],
      "mj-spacer" => [],
      "mj-table" => [],
      "mj-text" => [],
      "mj-wrapper" => ["mj-hero", "mj-raw", "mj-section"]
    }.freeze
  end
end
