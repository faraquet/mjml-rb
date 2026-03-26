require "cgi"
require "css_parser"
require "nokogiri"
require "set"
require_relative "components/accordion"
require_relative "components/attributes"
require_relative "components/body"
require_relative "components/breakpoint"
require_relative "components/button"
require_relative "components/carousel"
require_relative "components/carousel_image"
require_relative "components/group"
require_relative "components/head"
require_relative "components/hero"
require_relative "components/image"
require_relative "components/navbar"
require_relative "components/raw"
require_relative "components/text"
require_relative "components/divider"
require_relative "components/html_attributes"
require_relative "components/table"
require_relative "components/social"
require_relative "components/section"
require_relative "components/column"
require_relative "components/spacer"

module MjmlRb
  class Renderer
    DEFAULT_FONTS = {
      "Open Sans" => "https://fonts.googleapis.com/css?family=Open+Sans:300,400,500,700",
      "Droid Sans" => "https://fonts.googleapis.com/css?family=Droid+Sans:300,400,500,700",
      "Lato" => "https://fonts.googleapis.com/css?family=Lato:300,400,500,700",
      "Roboto" => "https://fonts.googleapis.com/css?family=Roboto:300,400,500,700",
      "Ubuntu" => "https://fonts.googleapis.com/css?family=Ubuntu:300,400,500,700"
    }.freeze

    DOCUMENT_RESET_CSS = <<~CSS.freeze
      #outlook a { padding:0; }
      body { margin:0;padding:0;-webkit-text-size-adjust:100%;-ms-text-size-adjust:100%; }
      table, td { border-collapse:collapse;mso-table-lspace:0pt;mso-table-rspace:0pt; }
      img { border:0;height:auto;line-height:100%; outline:none;text-decoration:none;-ms-interpolation-mode:bicubic; }
      p { display:block;margin:13px 0; }
    CSS

    OUTLOOK_DOCUMENT_SETTINGS = <<~HTML.chomp.freeze
      <!--[if mso]>
      <noscript>
      <xml>
      <o:OfficeDocumentSettings>
        <o:AllowPNG/>
        <o:PixelsPerInch>96</o:PixelsPerInch>
      </o:OfficeDocumentSettings>
      </xml>
      </noscript>
      <![endif]-->
    HTML

    OUTLOOK_GROUP_FIX = <<~HTML.chomp.freeze
      <!--[if lte mso 11]>
      <style type="text/css">
        .mj-outlook-group-fix { width:100% !important; }
      </style>
      <![endif]-->
    HTML

    def render(document, options = {})
      head = find_child(document, "mj-head")
      body = find_child(document, "mj-body")
      raise ArgumentError, "Missing <mj-body>" unless body

      context = build_context(head, options)
      context[:before_doctype] = root_file_start_raw(document)
      context[:lang] = options[:lang] || document["lang"] || "und"
      context[:dir] = options[:dir] || document["dir"] || "auto"
      context[:force_owa_desktop] = document["owa"] == "desktop"
      context[:printer_support] = options[:printer_support] || options[:printerSupport]
      context[:column_widths] = {}
      append_component_head_styles(document, context)
      content = render_node(body, context, parent: "mjml")
      build_html_document(content, context)
    end

    private

    def build_context(head, options)
      context = {
        title: "",
        preview: "",
        breakpoint: "480px",
        before_doctype: "",
        head_raw: [],
        component_head_styles: [],
        user_styles: [],
        inline_styles: [],
        html_attributes: {},
        fonts: DEFAULT_FONTS.merge(hash_or_empty(options[:fonts])),
        global_defaults: {},
        tag_defaults: {},
        classes: {},
        classes_default: {},
        inherited_mj_class: ""
      }

      return context unless head

      head.element_children.each do |node|
        component = component_for(node.tag_name)
        component.handle_head(node, context) if component&.respond_to?(:handle_head)
      end

      context
    end

    def build_html_document(content, context)
      content = minify_outlook_conditionals(content)
      content = apply_html_attributes_to_content(content, context)
      title = context[:title].to_s
      preview = context[:preview]
      head_raw = Array(context[:head_raw]).join("\n")
      before_doctype = context[:before_doctype].to_s
      font_tags = build_font_tags(content, context[:inline_styles], context[:fonts])
      media_queries_tags = build_media_queries_tags(
        context[:breakpoint],
        context[:column_widths],
        force_owa_desktop: context[:force_owa_desktop],
        printer_support: context[:printer_support]
      )
      component_styles_tag = build_style_tag(unique_strings(context[:component_head_styles]))
      user_styles_tag = build_style_tag(unique_strings(context[:user_styles]))
      preview_block = preview.empty? ? "" : %(<div style="display:none;font-size:1px;color:#ffffff;line-height:1px;max-height:0px;max-width:0px;opacity:0;overflow:hidden;">#{escape_html(preview)}</div>)
      html_attributes = {
        "lang" => context[:lang],
        "dir" => context[:dir],
        "xmlns" => "http://www.w3.org/1999/xhtml",
        "xmlns:v" => "urn:schemas-microsoft-com:vml",
        "xmlns:o" => "urn:schemas-microsoft-com:office:office"
      }
      body_style = style_join(
        "word-spacing" => "normal",
        "background-color" => context[:background_color]
      )

      html = <<~HTML
        <!doctype html>
        <html#{html_attrs(html_attributes)}>
          <head>
            <title>#{escape_html(title)}</title>
            <!--[if !mso]><!-->
            <meta http-equiv="X-UA-Compatible" content="IE=edge">
            <!--<![endif]-->
            <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style type="text/css">#{DOCUMENT_RESET_CSS}</style>
            #{OUTLOOK_DOCUMENT_SETTINGS}
            #{OUTLOOK_GROUP_FIX}
            #{font_tags}
            #{media_queries_tags}
            #{component_styles_tag}
            #{user_styles_tag}
            #{head_raw}
          </head>
          <body style="#{body_style}">
            #{preview_block}
            #{content}
          </body>
        </html>
      HTML

      html = apply_inline_styles(html, context)
      html = preserve_raw_tag_spacing(html)
      html = strip_internal_raw_markers(html)
      html = merge_outlook_conditionals(html)
      before_doctype.empty? ? html : "#{before_doctype}\n#{html}"
    end

    def build_font_tags(content, inline_styles, fonts)
      used_urls = Array(fonts).filter_map do |name, url|
        next if name.nil? || name.empty? || url.nil? || url.empty?
        next unless font_used?(content, inline_styles, name)

        url
      end.uniq
      return "" if used_urls.empty?

      links = used_urls.map { |url| %(<link href="#{escape_attr(url)}" rel="stylesheet" type="text/css">) }.join("\n")
      imports = used_urls.map { |url| "@import url(#{url});" }.join("\n")

      <<~HTML.chomp
        <!--[if !mso]><!-->
        #{links}
        <style type="text/css">
        #{imports}
        </style>
        <!--<![endif]-->
      HTML
    end

    def font_used?(content, inline_styles, font_name)
      escaped_name = Regexp.escape(font_name)
      content_regex = /"[^"]*font-family:[^"]*#{escaped_name}[^"]*"/mi
      inline_regex = /font-family:[^;}]*#{escaped_name}/mi

      content.to_s.match?(content_regex) || Array(inline_styles).any? { |style| style.to_s.match?(inline_regex) }
    end

    def render_children(node, context, parent:)
      with_inherited_mj_class(context, node) do
        node.children.map { |child| render_node(child, context, parent: parent) }.join("\n")
      end
    end

    def render_node(node, context, parent:)
      return escape_html(node.content.to_s) if node.text?
      return "<!--#{node.content}-->" if node.comment?

      attrs = resolved_attributes(node, context)
      if (component = component_for(node.tag_name))
        return component.render(tag_name: node.tag_name, node: node, context: context, attrs: attrs, parent: parent)
      end
      render_children(node, context, parent: node.tag_name)
    end

    def compute_column_widths(columns, context)
      total = columns.size
      return [100] if total == 0

      widths = columns.map do |col|
        w = col["width"]
        if w && w.to_s =~ /(\d+(?:\.\d+)?)\s*%/
          $1.to_f
        elsif w && w.to_s =~ /(\d+(?:\.\d+)?)\s*px/
          container = (context[:container_width] || "600px").to_f
          container > 0 ? ($1.to_f / container * 100) : nil
        else
          nil
        end
      end

      specified = widths.compact.sum
      unset_count = widths.count(&:nil?)

      if unset_count > 0
        remaining = [100.0 - specified, 0.0].max
        each_unset = remaining / unset_count
        widths.map { |w| w || each_unset }
      else
        widths
      end
    end

    def build_media_queries_tags(breakpoint, column_widths, force_owa_desktop: false, printer_support: false)
      widths = column_widths || {}
      return "" if widths.empty?

      base_rules = widths.map do |class_name, width_str|
        ".#{class_name} { width:#{width_str} !important; max-width: #{width_str}; }"
      end
      moz_rules = widths.map do |class_name, width_str|
        ".moz-text-html .#{class_name} { width:#{width_str} !important; max-width: #{width_str}; }"
      end
      owa_rules = widths.map do |class_name, width_str|
        "[owa] .#{class_name} { width:#{width_str} !important; max-width: #{width_str}; }"
      end

      bp = breakpoint.to_s.strip
      parts = []

      if bp.empty?
        parts << "<style type=\"text/css\">\n#{base_rules.join("\n")}\n</style>"
        parts << "<style type=\"text/css\">\n#{moz_rules.join("\n")}\n</style>"
      else
        parts << "<style type=\"text/css\">\n@media only screen and (min-width:#{bp}) {\n#{base_rules.join("\n")}\n}\n</style>"
        parts << "<style media=\"screen and (min-width:#{bp})\">\n#{moz_rules.join("\n")}\n</style>"
      end

      if printer_support
        parts << "<style type=\"text/css\">\n@media only print {\n#{base_rules.join("\n")}\n}\n</style>"
      end

      if force_owa_desktop
        parts << "<style type=\"text/css\">\n#{owa_rules.join("\n")}\n</style>"
      end
      parts.join("\n")
    end

    def build_style_tag(styles)
      return "" if styles.empty?

      "<style type=\"text/css\">#{styles.join("\n")}</style>"
    end

    def merge_outlook_conditionals(html)
      # MJML post-processes the HTML to merge adjacent Outlook conditional comments.
      # e.g. <![endif]-->\n<!--[if mso | IE]> become a single conditional block.
      html.gsub(/<!\[endif\]-->\s*<!--\[if mso \| IE\]>/m, "")
    end

    def minify_outlook_conditionals(html)
      html.gsub(/(<!--\[if\s[^\]]+\]>)([\s\S]*?)(<!\[endif\]-->)/m) do
        prefix = Regexp.last_match(1)
        content = Regexp.last_match(2)
        suffix = Regexp.last_match(3)

        processed = content
                    .gsub(/(^|>)(\s+)(<|$)/m, '\1\3')
                    .gsub(/\s{2,}/m, " ")

        "#{prefix}#{processed}#{suffix}"
      end
    end

    def apply_html_attributes_to_content(content, context)
      rules = context[:html_attributes] || {}
      return content if rules.empty?

      root = html_attributes_fragment_root(content, context)

      rules.each do |selector, attrs|
        next if selector.empty? || attrs.empty?

        select_nodes(root, selector).each do |node|
          attrs.each do |name, value|
            node[name] = value.to_s
          end
        end
      end

      root.inner_html
    end

    def html_attributes_fragment_root(content, context)
      wrapper_attrs = {
        "data-mjml-body-root" => "true",
        "lang" => context[:lang],
        "dir" => context[:dir]
      }
      fragment = Nokogiri::HTML::DocumentFragment.parse("<div#{html_attrs(wrapper_attrs)}>#{content}</div>")
      fragment.at_css("div[data-mjml-body-root='true']")
    end

    def apply_inline_styles(html, context)
      css_blocks = unique_strings(context[:inline_styles]).reject { |css| css.nil? || css.strip.empty? }
      return html if css_blocks.empty?

      document = parse_html_document(html)
      rules, = parse_inline_css_rules(css_blocks.join("\n"))
      merged_declarations_by_node = {}
      touched_properties_by_node = Hash.new { |hash, node| hash[node] = Set.new }

      rules.each do |selector, declarations|
        next if selector.empty? || declarations.empty?

        select_nodes(document, selector).each do |node|
          existing = merged_declarations_by_node[node] ||= begin
            source = node["data-mjml-raw"] == "true" ? :inline : :css
            parsed = parse_css_declarations(node["style"].to_s, source: source)
            touched_properties_by_node[node].merge(parsed.keys & HTML_ATTRIBUTE_SYNC_PROPERTIES.to_a) if source == :inline
            parsed
          end
          merge_inline_declarations!(existing, declarations, touched_properties_by_node[node])
        end
      end

      merged_declarations_by_node.each do |node, declarations|
        finalize_inline_style!(node, declarations, touched_properties_by_node[node])
      end

      document.to_html
    end

    def parse_html_document(html)
      if defined?(Nokogiri::HTML5)
        Nokogiri::HTML5(html)
      else
        Nokogiri::HTML(html)
      end
    end

    def select_nodes(document, selector)
      document.css(selector)
    rescue Nokogiri::CSS::SyntaxError, Nokogiri::XML::XPath::SyntaxError
      fallback_select_nodes(document, selector)
    end

    def fallback_select_nodes(document, selector)
      return [] unless selector.include?(":lang(")

      lang_values = selector.scan(/:lang\(([^)]+)\)/).flatten.map do |value|
        value.to_s.strip.gsub(/\A['"]|['"]\z/, "").downcase
      end.reject(&:empty?)
      return [] if lang_values.empty?

      base_selector = selector.gsub(/:lang\(([^)]+)\)/, "").strip
      base_selector = "*" if base_selector.empty?

      document.css(base_selector).select do |node|
        lang_values.all? { |lang| lang_matches?(node, lang) }
      end
    rescue Nokogiri::CSS::SyntaxError, Nokogiri::XML::XPath::SyntaxError
      []
    end

    def lang_matches?(node, lang)
      current = node

      while current
        value = current["lang"]
        if value && !value.empty?
          normalized = value.downcase
          return normalized == lang || normalized.start_with?("#{lang}-")
        end
        current = current.parent
      end

      false
    end

    def parse_inline_css_rules(css)
      parser = CssParser::Parser.new
      parser.add_block!(css.to_s)

      rules = []
      parser.each_rule_set do |rule_set, media_types|
        # Only inline rules not inside @media blocks; css_parser stores
        # top-level rules under the :all media type.
        next unless media_types == [:all]

        rule_set.each_selector do |selector, declarations_str, specificity|
          selector = selector.strip
          # Skip @-rules like @font-face that css_parser yields as selectors
          next if selector.start_with?("@")

          declaration_map = parse_css_declarations(declarations_str)
          rules << [selector, declaration_map, specificity]
        end
      end

      # Sort rules by specificity (ascending). With the "last wins" merge
      # strategy, higher-specificity rules applied later correctly override
      # lower-specificity ones — matching CSS cascade behavior.
      sorted = rules.sort_by.with_index { |(_, _, spec), idx| [spec, idx] }
                    .map { |sel, decl, _| [sel, decl] }

      [sorted, ""]
    end

    def css_specificity(selector)
      CssParser.calculate_specificity(selector.to_s)
    end

    def parse_css_declarations(declarations, source: :css)
      return {} if declarations.nil? || declarations.to_s.strip.empty?

      rule_set = CssParser::RuleSet.new(block: declarations.to_s)
      result = {}
      rule_set.each_declaration do |property, value, important|
        next if property.nil? || property.empty? || value.nil? || value.empty?

        result[property] = {
          value: value,
          important: important,
          source: source
        }
      end
      result
    end

    def merge_inline_declarations!(existing, declarations, touched_properties)
      declarations.each do |property, value|
        merged = merge_css_declaration(existing[property], value)
        next if merged.equal?(existing[property])

        existing.delete(property)
        existing[property] = merged
        touched_properties << property
      end
    end

    def finalize_inline_style!(node, declarations, touched_properties)
      sync_html_attributes!(node, declarations, touched_properties)
      node["style"] = serialize_css_declarations(declarations)
    end

    # Sync HTML attributes from inlined CSS declarations.
    # Mirrors Juice's attribute syncing: width/height on TABLE/TD/TH/IMG,
    # and style-to-attribute mappings (bgcolor, background, align, valign)
    # on table-related elements.
    # See: https://github.com/Automattic/juice/blob/master/lib/inline.js
    WIDTH_HEIGHT_ELEMENTS = Set.new(%w[table td th img]).freeze
    TABLE_ELEMENTS = Set.new(%w[table th tr td caption colgroup col thead tbody tfoot]).freeze
    STYLE_TO_ATTRIBUTE = {
      "background-color" => "bgcolor",
      "background-image" => "background",
      "text-align" => "align",
      "vertical-align" => "valign"
    }.freeze
    HTML_ATTRIBUTE_SYNC_PROPERTIES = Set.new((%w[width height] + STYLE_TO_ATTRIBUTE.keys)).freeze

    def sync_html_attributes!(node, declarations, touched_properties = nil)
      tag = node.name.downcase

      # Sync width/height on TABLE, TD, TH, IMG
      if WIDTH_HEIGHT_ELEMENTS.include?(tag)
        %w[width height].each do |prop|
          next if touched_properties && !touched_properties.include?(prop)

          css_value = declaration_value(declarations[prop])
          next if css_value.nil? || css_value.empty?
          next if tag == "img" && prop == "width" && css_value.include?("%")

          # Convert CSS px values to plain numbers for HTML attributes;
          # keep other values (auto, %) as-is.
          html_value = css_value.sub(/px\z/i, "")
          node[prop] = html_value
        end
      end

      # Sync style-to-attribute mappings on table elements
      if TABLE_ELEMENTS.include?(tag)
        STYLE_TO_ATTRIBUTE.each do |css_prop, html_attr|
          next if touched_properties && !touched_properties.include?(css_prop)

          css_value = declaration_value(declarations[css_prop])
          next if css_value.nil? || css_value.empty?

          case html_attr
          when "bgcolor"
            next if %w[none transparent].include?(css_value.downcase)
            node[html_attr] = css_value
          when "background"
            # Extract url(...) from background-image
            url = css_value[/url\(['"]?([^'")]+)['"]?\)/i, 1]
            node[html_attr] = url if url
          when "align"
            node[html_attr] = css_value
          when "valign"
            node[html_attr] = css_value
          end
        end
      end
    end

    def merge_css_declaration(existing, incoming)
      return incoming if existing.nil?
      return incoming if incoming[:important] && !existing[:important]
      return existing if existing[:source] == :inline
      return existing if existing[:important] && !incoming[:important]

      incoming
    end

    def declaration_value(declaration)
      declaration && declaration[:value]
    end

    def serialize_css_declarations(declarations)
      ordered_css_declarations(declarations).map do |property, declaration|
        "#{property}: #{declaration[:value]}"
      end.join("; ")
    end

    SHORTHAND_LONGHAND_FAMILIES = {
      "background" => /\Abackground-/,
      "border" => /\Aborder(?:-(?!collapse|spacing)[a-z-]+)?\z/,
      "border-radius" => /\Aborder-(?:top|bottom)-(?:left|right)-radius\z/,
      "font" => /\Afont-/,
      "list-style" => /\Alist-style-/,
      "margin" => /\Amargin-(?:top|right|bottom|left)\z/,
      "padding" => /\Apadding-(?:top|right|bottom|left)\z/
    }.freeze

    def ordered_css_declarations(declarations)
      ordered = declarations.to_a

      SHORTHAND_LONGHAND_FAMILIES.each do |shorthand, longhand_pattern|
        family_indexes = ordered.each_index.select do |index|
          property = ordered[index][0]
          property == shorthand || property.match?(longhand_pattern)
        end
        next if family_indexes.length < 2

        family_entries = family_indexes.map.with_index do |declaration_index, original_family_index|
          [ordered[declaration_index], original_family_index]
        end
        next unless family_entries.any? { |((_, declaration), _)| declaration[:important] }
        next unless family_entries.any? { |((_, declaration), _)| !declaration[:important] }

        reordered_entries = family_entries.sort_by do |((_, declaration), original_family_index)|
          [declaration[:important] ? 1 : 0, original_family_index]
        end.map(&:first)

        family_indexes.each_with_index do |declaration_index, reordered_index|
          ordered[declaration_index] = reordered_entries[reordered_index]
        end
      end

      ordered
    end

    def append_component_head_styles(document, context)
      all_tags = collect_tag_names(document)

      component_registry.each_value.uniq.each do |component|
        next unless component.respond_to?(:head_style)

        style = if component.method(:head_style).arity == 1
                  component.head_style(context[:breakpoint])
                else
                  component.head_style
                end
        next if style.nil? || style.empty?

        tags = if component.respond_to?(:head_style_tags)
                 component.head_style_tags
               else
                 component.tags
               end
        next unless Array(tags).any? { |tag| all_tags.include?(tag) }

        context[:component_head_styles] << style
      end
    end

    def component_for(tag_name)
      component_registry[tag_name]
    end

    def component_registry
      @component_registry ||= begin
        registry = {}
        # Register component classes here as they are implemented.
        register_component(registry, Components::Body.new(self))
        register_component(registry, Components::Head.new(self))
        register_component(registry, Components::Attributes.new(self))
        register_component(registry, Components::Breakpoint.new(self))
        register_component(registry, Components::Accordion.new(self))
        register_component(registry, Components::Button.new(self))
        register_component(registry, Components::Carousel.new(self))
        register_component(registry, Components::CarouselImage.new(self))
        register_component(registry, Components::Group.new(self))
        register_component(registry, Components::Hero.new(self))
        register_component(registry, Components::Image.new(self))
        register_component(registry, Components::Navbar.new(self))
        register_component(registry, Components::Raw.new(self))
        register_component(registry, Components::Text.new(self))
        register_component(registry, Components::Divider.new(self))
        register_component(registry, Components::HtmlAttributes.new(self))
        register_component(registry, Components::Table.new(self))
        register_component(registry, Components::Social.new(self))
        register_component(registry, Components::Section.new(self))
        register_component(registry, Components::Column.new(self))
        register_component(registry, Components::Spacer.new(self))

        MjmlRb.component_registry.custom_components.each do |klass|
          register_component(registry, klass.new(self))
        end

        registry
      end
    end

    def register_component(registry, component)
      component.tags.each { |tag| registry[tag] = component }
    end

    def resolved_attributes(node, context)
      attrs = {}
      attrs.merge!(context[:global_defaults] || {})
      attrs.merge!(context[:tag_defaults][node.tag_name] || {})

      node_classes = node["mj-class"].to_s.split(/\s+/).reject(&:empty?)
      class_attrs = node_classes.each_with_object({}) do |klass, memo|
        mj_class_attrs = (context[:classes] || {})[klass] || {}
        if memo["css-class"] && mj_class_attrs["css-class"]
          memo["css-class"] = "#{memo["css-class"]} #{mj_class_attrs["css-class"]}"
        end
        memo.merge!(mj_class_attrs)
      end
      attrs.merge!(class_attrs)

      inherited_classes = context[:inherited_mj_class].to_s.split(/\s+/).reject(&:empty?)
      inherited_classes.each do |klass|
        attrs.merge!(((context[:classes_default] || {})[klass] || {})[node.tag_name] || {})
      end

      attrs.merge!(node_string_attributes(node))
      attrs
    end

    def html_inner(node)
      node.inner_html
    end

    def raw_inner(node)
      # For ending-tag nodes whose content was preserved as raw HTML by the parser.
      # The parser marks these with data-mjml-ending-tag; their children are CDATA
      # nodes containing the raw HTML content.
      if node.element? && node["data-mjml-ending-tag"]
        return node.children.select { |c| c.cdata? || c.text? }.map(&:content).join
      end

      node.children.map do |child|
        if child.text?
          child.content.to_s
        else
          child.to_html
        end
      end.join
    end

    def annotate_raw_html(content)
      return content if content.nil? || content.empty? || !content.include?("<")
      content.gsub(/<(?!\/|!)([A-Za-z][\w:-]*)(\s[^<>]*?)?(\s*\/?)>/) do
        tag_name = Regexp.last_match(1)
        attrs = Regexp.last_match(2).to_s
        closing = Regexp.last_match(3).to_s
        "<#{tag_name}#{attrs} data-mjml-raw=\"true\"#{closing}>"
      end
    end

    def strip_internal_raw_markers(html)
      html.gsub(/\sdata-mjml-raw=(['"])true\1/, "")
    end

    def preserve_raw_tag_spacing(html)
      html.gsub(
        /(<[^>]+data-mjml-raw=(['"])true\2[^>]*>)([ \t]+)(<[^\/!][^>]+data-mjml-raw=(['"])true\5[^>]*>)/
      ) do
        "#{Regexp.last_match(1)}#{encode_whitespace_entities(Regexp.last_match(3))}#{Regexp.last_match(4)}"
      end
    end

    def encode_whitespace_entities(text)
      text.to_s.gsub(" ", "&#32;").gsub("\t", "&#9;")
    end

    def style_join(hash)
      hash.each_with_object([]) do |(key, value), memo|
        next if value.nil? || value.to_s.empty?
        memo << "#{key}:#{value}"
      end.join(";")
    end

    def hash_or_empty(value)
      value.is_a?(Hash) ? value : {}
    end

    def find_child(node, tag_name)
      node.element_children.find { |child| child.tag_name == tag_name }
    end

    def with_inherited_mj_class(context, node)
      previous = context[:inherited_mj_class]
      current = node["mj-class"]
      context[:inherited_mj_class] = (current && !current.empty?) ? current : previous
      yield
    ensure
      context[:inherited_mj_class] = previous
    end

    def root_file_start_raw(document)
      document.element_children.filter_map do |child|
        next unless child.tag_name == "mj-raw"
        next unless child["position"] == "file-start"

        raw_inner(child)
      end.join("\n")
    end

    def collect_tag_names(node, result = Set.new)
      return result unless node.respond_to?(:tag_name)

      result << node.tag_name
      node.children.each { |child| collect_tag_names(child, result) if child.respond_to?(:children) }
      result
    end

    # Internal-only attributes set by the parser for metadata tracking.
    # These are excluded from the public attributes hash; data-mjml-raw
    # is intentionally kept because it is used by the rendering pipeline.
    INTERNAL_ATTRIBUTES = %w[data-mjml-file data-mjml-ending-tag].freeze

    def node_string_attributes(node)
      result = {}
      node.attributes.each do |name, attr|
        next if INTERNAL_ATTRIBUTES.include?(name)
        result[name] = attr.respond_to?(:value) ? attr.value : attr.to_s
      end
      result
    end

    def escape_html(value)
      CGI.escapeHTML(value.to_s)
    end

    def escape_attr(value)
      CGI.escapeHTML(value.to_s)
    end

    # Match npm MJML behaviour: omit only nil/undefined attributes.
    # lodash `omitBy(attributes, isNil)` keeps empty strings, so we do the same.
    # This preserves semantically meaningful empty values like `alt=""`.
    def html_attrs(hash)
      attrs = hash.each_with_object([]) do |(key, value), memo|
        next if value.nil?

        memo << %(#{key}="#{escape_attr(value)}")
      end
      return "" if attrs.empty?

      " #{attrs.join(' ')}"
    end

    def unique_strings(values)
      seen = Set.new
      Array(values).each_with_object([]) do |value, memo|
        next if value.nil? || value.empty?
        next unless seen.add?(value)

        memo << value
      end
    end
  end
end
