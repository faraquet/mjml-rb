require "cgi"
require "nokogiri"
require_relative "components/accordion"
require_relative "components/attributes"
require_relative "components/body"
require_relative "components/breakpoint"
require_relative "components/button"
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
      "Roboto" => "https://fonts.googleapis.com/css?family=Roboto:300,400,500,700"
    }.freeze

    DOCUMENT_RESET_CSS = <<~CSS.freeze
      #outlook a { padding:0; }
      body { margin:0;padding:0;-webkit-text-size-adjust:100%;-ms-text-size-adjust:100%; }
      table, td { border-collapse:collapse;mso-table-lspace:0pt;mso-table-rspace:0pt; }
      img { border:0;height:auto;line-height:100%; outline:none;text-decoration:none;-ms-interpolation-mode:bicubic; }
      p { display:block;margin:13px 0; }
    CSS

    def render(document, options = {})
      head = find_child(document, "mj-head")
      body = find_child(document, "mj-body")
      raise ArgumentError, "Missing <mj-body>" unless body

      context = build_context(head, options)
      context[:before_doctype] = root_file_start_raw(document)
      context[:lang] = options[:lang] || document.attributes["lang"] || "und"
      context[:dir] = options[:dir] || document.attributes["dir"] || "auto"
      context[:column_widths] = {}
      append_component_head_styles(document, context)
      content = render_node(body, context, parent: "mjml")
      append_column_width_styles(context)
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
        head_styles: [],
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
        case node.tag_name
        when "mj-title"
          context[:title] = node.text_content.strip
        when "mj-preview"
          context[:preview] = node.text_content.strip
        when "mj-style"
          context[:head_styles] << node.text_content
          context[:inline_styles] << node.text_content if node.attributes["inline"] == "inline"
        when "mj-font"
          name = node.attributes["name"]
          href = node.attributes["href"]
          context[:fonts][name] = href if name && href
        when "mj-breakpoint"
          width = node.attributes["width"].to_s.strip
          context[:breakpoint] = width unless width.empty?
        when "mj-attributes"
          if (component = component_for(node.tag_name)) && component.respond_to?(:handle_head)
            component.handle_head(node, context)
          else
            absorb_attribute_node(node, context)
          end
        when "mj-html-attributes"
          absorb_html_attributes_node(node, context)
        when "mj-raw"
          context[:head_raw] << raw_inner(node)
        end
      end

      context
    end

    def absorb_attribute_node(attributes_node, context)
      attributes_node.element_children.each do |child|
        case child.tag_name
        when "mj-all"
          context[:global_defaults].merge!(child.attributes)
        when "mj-class"
          name = child.attributes["name"]
          next unless name

          context[:classes][name] = child.attributes.reject { |k, _| k == "name" }
        else
          context[:tag_defaults][child.tag_name] ||= {}
          context[:tag_defaults][child.tag_name].merge!(child.attributes)
        end
      end
    end

    def absorb_html_attributes_node(html_attributes_node, context)
      html_attributes_node.element_children.each do |selector|
        next unless selector.tag_name == "mj-selector"

        path = selector.attributes["path"].to_s.strip
        next if path.empty?

        custom_attrs = selector.element_children.each_with_object({}) do |child, memo|
          next unless child.tag_name == "mj-html-attribute"

          name = child.attributes["name"].to_s.strip
          next if name.empty?

          memo[name] = child.text_content
        end
        next if custom_attrs.empty?

        context[:html_attributes][path] ||= {}
        context[:html_attributes][path].merge!(custom_attrs)
      end
    end

    def build_html_document(content, context)
      title = context[:title].to_s
      preview = context[:preview]
      head_styles = ([DOCUMENT_RESET_CSS] + unique_strings(context[:head_styles])).join("\n")
      head_raw = Array(context[:head_raw]).join("\n")
      before_doctype = context[:before_doctype].to_s
      font_links = context[:fonts].values.uniq.map { |href| %(<link href="#{escape_attr(href)}" rel="stylesheet" type="text/css">) }.join("\n")
      preview_block = preview.empty? ? "" : %(<div style="display:none;max-height:0;overflow:hidden;opacity:0;">#{escape_html(preview)}</div>)
      html_attributes = { "lang" => context[:lang], "dir" => context[:dir] }
      body_style = style_join(
        "margin" => "0",
        "padding" => "0",
        "background" => context[:background_color] || "#ffffff"
      )

      html = <<~HTML
        <!doctype html>
        <html#{html_attrs(html_attributes)}>
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>#{escape_html(title)}</title>
            #{font_links}
            <style type="text/css">#{head_styles}</style>
            #{head_raw}
          </head>
          <body style="#{body_style}">
            #{preview_block}
            #{content}
          </body>
        </html>
      HTML

      html = apply_html_attributes(html, context)
      html = apply_inline_styles(html, context)
      before_doctype.empty? ? html : "#{before_doctype}\n#{html}"
    end

    def render_children(node, context, parent:)
      with_inherited_mj_class(context, node) do
        node.children.map { |child| render_node(child, context, parent: parent) }.join("\n")
      end
    end

    def render_node(node, context, parent:)
      return escape_html(node.content.to_s) if node.text?
      return "" if node.comment?

      attrs = resolved_attributes(node, context)
      if (component = component_for(node.tag_name))
        return component.render(tag_name: node.tag_name, node: node, context: context, attrs: attrs, parent: parent)
      end

      case node.tag_name
      when "mj-group"
        render_group(node, context)
      else
        render_children(node, context, parent: node.tag_name)
      end
    end

    def render_group(node, context, width_pct = 100)
      items = node.element_children.select { |e| e.tag_name == "mj-column" }
      widths = compute_column_widths(items, context)
      with_inherited_mj_class(context, node) do
        items.each_with_index.map do |item, i|
          context[:_column_width_pct] = widths[i]
          render_node(item, context, parent: "mj-group")
        end.join("\n")
      end
    end

    def compute_column_widths(columns, context)
      total = columns.size
      return [100] if total == 0

      widths = columns.map do |col|
        w = col.attributes["width"]
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

    def append_column_width_styles(context)
      widths = context[:column_widths] || {}
      return if widths.empty?

      css = widths.map do |suffix, pct|
        ".mj-column-per-#{suffix} { width:#{pct}% !important; max-width: #{pct}%; }"
      end.join("\n")
      breakpoint = context[:breakpoint].to_s.strip
      if breakpoint.empty?
        context[:head_styles] << css
      else
        context[:head_styles] << "@media only screen and (min-width:#{breakpoint}) {\n#{css}\n}"
      end
    end

    def merge_outlook_conditionals(html)
      # MJML post-processes the HTML to merge adjacent Outlook conditional comments.
      # e.g. <![endif]-->\n<!--[if mso | IE]> become a single conditional block.
      html.gsub(/<!\[endif\]-->\s*<!--\[if mso \| IE\]>/m, "")
    end

    def apply_html_attributes(html, context)
      rules = context[:html_attributes] || {}
      return html if rules.empty?

      document = Nokogiri::HTML(html)

      rules.each do |selector, attrs|
        next if selector.empty? || attrs.empty?

        begin
          document.css(selector).each do |node|
            attrs.each do |name, value|
              node[name] = value.to_s
            end
          end
        rescue Nokogiri::CSS::SyntaxError
          next
        end
      end

      document.to_html
    end

    def apply_inline_styles(html, context)
      css_blocks = unique_strings(context[:inline_styles]).reject { |css| css.nil? || css.strip.empty? }
      return html if css_blocks.empty?

      document = Nokogiri::HTML(html)
      parse_inline_css_rules(css_blocks.join("\n")).each do |selector, declarations|
        next if selector.empty? || declarations.empty?

        begin
          document.css(selector).each do |node|
            merge_inline_style!(node, declarations)
          end
        rescue Nokogiri::CSS::SyntaxError
          next
        end
      end

      document.to_html
    end

    def parse_inline_css_rules(css)
      stripped_css = strip_css_comments(css.to_s)
      plain_css = strip_css_at_rules(stripped_css)

      plain_css.scan(/([^{}]+)\{([^{}]+)\}/m).flat_map do |selector_group, declarations|
        selectors = selector_group.split(",").map(&:strip).reject(&:empty?)
        declaration_map = parse_css_declarations(declarations)
        selectors.map { |selector| [selector, declaration_map] }
      end
    end

    def strip_css_comments(css)
      css.gsub(%r{/\*.*?\*/}m, "")
    end

    def strip_css_at_rules(css)
      result = +""
      index = 0

      while index < css.length
        if css[index] == "@"
          brace_index = css.index("{", index)
          semicolon_index = css.index(";", index)

          if semicolon_index && (brace_index.nil? || semicolon_index < brace_index)
            index = semicolon_index + 1
            next
          end

          if brace_index
            depth = 1
            cursor = brace_index + 1
            while cursor < css.length && depth.positive?
              depth += 1 if css[cursor] == "{"
              depth -= 1 if css[cursor] == "}"
              cursor += 1
            end
            index = cursor
            next
          end
        end

        result << css[index]
        index += 1
      end

      result
    end

    def parse_css_declarations(declarations)
      declarations.split(";").each_with_object({}) do |entry, memo|
        property, value = entry.split(":", 2).map { |part| part&.strip }
        next if property.nil? || property.empty? || value.nil? || value.empty?

        memo[property] = value.sub(/\s*!important\s*\z/, "").strip
      end
    end

    def merge_inline_style!(node, declarations)
      existing = parse_css_declarations(node["style"].to_s)
      declarations.each do |property, value|
        existing[property] = value
      end
      node["style"] = existing.map { |property, value| "#{property}: #{value}" }.join("; ")
    end

    def append_component_head_styles(document, context)
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
        next unless Array(tags).any? { |tag| contains_tag?(document, tag) }

        context[:head_styles] << style
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
        register_component(registry, Components::Attributes.new(self))
        register_component(registry, Components::Breakpoint.new(self))
        register_component(registry, Components::Accordion.new(self))
        register_component(registry, Components::Button.new(self))
        register_component(registry, Components::Hero.new(self))
        register_component(registry, Components::Image.new(self))
        register_component(registry, Components::Navbar.new(self))
        register_component(registry, Components::Raw.new(self))
        register_component(registry, Components::Text.new(self))
        register_component(registry, Components::Divider.new(self))
        register_component(registry, Components::Table.new(self))
        register_component(registry, Components::Social.new(self))
        register_component(registry, Components::Section.new(self))
        register_component(registry, Components::Column.new(self))
        register_component(registry, Components::Spacer.new(self))
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

      node_classes = node.attributes["mj-class"].to_s.split(/\s+/).reject(&:empty?)
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

      attrs.merge!(node.attributes)
      attrs
    end

    def html_inner(node)
      if node.respond_to?(:children)
        node.children.map do |child|
          if child.text?
            escape_html(child.content.to_s)
          elsif child.comment?
            "<!--#{child.content}-->"
          else
            serialize_node(child)
          end
        end.join
      else
        escape_html(node.text_content)
      end
    end

    def raw_inner(node)
      if node.respond_to?(:children)
        node.children.map do |child|
          if child.text?
            child.content.to_s
          elsif child.comment?
            "<!--#{child.content}-->"
          else
            serialize_node(child)
          end
        end.join
      else
        node.text_content
      end
    end

    def serialize_node(node)
      attrs = node.attributes.map { |k, v| %( #{k}="#{escape_attr(v)}") }.join
      return "<#{node.tag_name}#{attrs} />" if node.children.empty?

      inner = node.children.map { |child| child.text? ? child.content.to_s : serialize_node(child) }.join
      "<#{node.tag_name}#{attrs}>#{inner}</#{node.tag_name}>"
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
      current = node.attributes["mj-class"]
      context[:inherited_mj_class] = (current && !current.empty?) ? current : previous
      yield
    ensure
      context[:inherited_mj_class] = previous
    end

    def root_file_start_raw(document)
      document.element_children.filter_map do |child|
        next unless child.tag_name == "mj-raw"
        next unless child.attributes["position"] == "file-start"

        raw_inner(child)
      end.join("\n")
    end

    def contains_tag?(node, tag_name)
      return false unless node.respond_to?(:tag_name)
      return true if node.tag_name == tag_name

      node.children.any? { |child| child.respond_to?(:children) && contains_tag?(child, tag_name) }
    end

    def escape_html(value)
      CGI.escapeHTML(value.to_s)
    end

    def escape_attr(value)
      CGI.escapeHTML(value.to_s)
    end

    def html_attrs(hash)
      attrs = hash.each_with_object([]) do |(key, value), memo|
        next if value.nil? || value.to_s.empty?
        memo << %(#{key}="#{escape_attr(value)}")
      end
      return "" if attrs.empty?

      " #{attrs.join(' ')}"
    end

    def unique_strings(values)
      Array(values).each_with_object([]) do |value, memo|
        next if value.nil? || value.empty?
        next if memo.include?(value)

        memo << value
      end
    end
  end
end
