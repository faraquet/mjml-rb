require "cgi"
require_relative "components/accordion"
require_relative "components/body"
require_relative "components/button"
require_relative "components/image"
require_relative "components/text"
require_relative "components/divider"
require_relative "components/table"

module MjmlRb
  class Renderer
    DEFAULT_FONTS = {
      "Open Sans" => "https://fonts.googleapis.com/css?family=Open+Sans:300,400,500,700",
      "Droid Sans" => "https://fonts.googleapis.com/css?family=Droid+Sans:300,400,500,700",
      "Lato" => "https://fonts.googleapis.com/css?family=Lato:300,400,500,700",
      "Roboto" => "https://fonts.googleapis.com/css?family=Roboto:300,400,500,700",
      "Ubuntu" => "https://fonts.googleapis.com/css?family=Ubuntu:300,400,500,700"
    }.freeze
    def render(document, options = {})
      head = find_child(document, "mj-head")
      body = find_child(document, "mj-body")
      raise ArgumentError, "Missing <mj-body>" unless body

      context = build_context(head, options)
      context[:lang] = options[:lang] || document.attributes["lang"] || "en"
      context[:dir] = options[:dir] || document.attributes["dir"]
      context[:column_widths] = []
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
        head_styles: [],
        body_styles: [],
        fonts: DEFAULT_FONTS.merge(hash_or_empty(options[:fonts])),
        global_defaults: {},
        tag_defaults: {},
        classes: {}
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
        when "mj-font"
          name = node.attributes["name"]
          href = node.attributes["href"]
          context[:fonts][name] = href if name && href
        when "mj-attributes"
          absorb_attribute_node(node, context)
        when "mj-raw"
          context[:body_styles] << raw_inner(node)
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

    def build_html_document(content, context)
      title = context[:title].empty? ? "MJML Document" : context[:title]
      preview = context[:preview]
      head_styles = context[:head_styles].join("\n")
      font_links = context[:fonts].values.uniq.map { |href| %(<link href="#{escape_attr(href)}" rel="stylesheet" type="text/css">) }.join("\n")
      preview_block = preview.empty? ? "" : %(<div style="display:none;max-height:0;overflow:hidden;opacity:0;">#{escape_html(preview)}</div>)
      html_attributes = { "lang" => context[:lang], "dir" => context[:dir] }
      body_style = style_join(
        "margin" => "0",
        "padding" => "0",
        "background" => context[:background_color] || "#ffffff"
      )

      <<~HTML
        <!doctype html>
        <html#{html_attrs(html_attributes)}>
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>#{escape_html(title)}</title>
            #{font_links}
            <style type="text/css">#{head_styles}</style>
          </head>
          <body style="#{body_style}">
            #{preview_block}
            #{content}
          </body>
        </html>
      HTML
    end

    def render_children(node, context, parent:)
      node.children.map { |child| render_node(child, context, parent: parent) }.join("\n")
    end

    def render_node(node, context, parent:)
      return escape_html(node.content.to_s) if node.text?
      return "" if node.comment?

      attrs = resolved_attributes(node, context)
      if (component = component_for(node.tag_name))
        return component.render(tag_name: node.tag_name, node: node, context: context, attrs: attrs, parent: parent)
      end

      case node.tag_name
      when "mj-wrapper"
        render_wrapper_element(node, context, attrs)
      when "mj-section"
        render_section_element(node, context, attrs)
      when "mj-group"
        render_group(node, context)
      when "mj-column"
        render_column(node, context, attrs, 100)
      when "mj-spacer"
        render_spacer(attrs)
      when "mj-raw"
        raw_inner(node)
      when "mj-hero"
        render_hero(node, context, attrs)
      when "mj-social"
        render_social(node, context, attrs)
      when "mj-social-element"
        render_social_element(node, attrs)
      when "mj-navbar"
        render_navbar(node, context, attrs)
      when "mj-navbar-link"
        render_navbar_link(node, attrs, parent: parent)
      else
        render_children(node, context, parent: node.tag_name)
      end
    end

    def render_section_element(node, context, attrs)
      container_width = context[:container_width] || "600px"
      css_class = attrs["css-class"]
      bg_color = attrs["background-color"]
      padding = attrs["padding"] || "20px 0"

      div_style = style_join(
        "margin" => "0px auto",
        "max-width" => container_width
      )
      td_style = style_join(
        "direction" => "ltr",
        "font-size" => "0px",
        "padding" => padding,
        "padding-top" => attrs["padding-top"],
        "padding-bottom" => attrs["padding-bottom"],
        "padding-left" => attrs["padding-left"],
        "padding-right" => attrs["padding-right"],
        "text-align" => "center",
        "background-color" => bg_color
      )
      td_attrs = {"style" => td_style, "align" => "center"}
      td_attrs["bgcolor"] = bg_color if bg_color
      div_attrs = {"class" => css_class, "style" => div_style}
      inner = render_section_columns(node, context)

      %(<div#{html_attrs(div_attrs)}><table align="center" border="0" cellpadding="0" cellspacing="0" role="presentation" style="width:100%;" width="100%"><tbody><tr><td#{html_attrs(td_attrs)}>#{inner}</td></tr></tbody></table></div>)
    end

    def render_wrapper_element(node, context, attrs)
      container_width = context[:container_width] || "600px"
      css_class = attrs["css-class"]
      bg_color = attrs["background-color"]
      padding = attrs["padding"] || "20px 0"

      div_style = style_join(
        "background-color" => bg_color,
        "margin" => "0px auto",
        "max-width" => container_width
      )
      td_style = style_join(
        "direction" => "ltr",
        "font-size" => "0px",
        "padding" => padding,
        "text-align" => "center"
      )
      div_attrs = {"class" => css_class, "style" => div_style}
      children = render_children(node, context, parent: "mj-wrapper")

      %(<div#{html_attrs(div_attrs)}><table align="center" border="0" cellpadding="0" cellspacing="0" role="presentation" style="width:100%;" width="100%"><tbody><tr><td style="#{td_style}">#{children}</td></tr></tbody></table></div>)
    end

    def render_section_columns(node, context)
      columns = node.element_children.select { |e| %w[mj-column mj-group].include?(e.tag_name) }
      return render_children(node, context, parent: "mj-section") if columns.empty?

      widths = compute_column_widths(columns, context)
      columns.each_with_index.map do |col, i|
        attrs = resolved_attributes(col, context)
        if col.tag_name == "mj-group"
          render_group(col, context, widths[i])
        else
          render_column(col, context, attrs, widths[i])
        end
      end.join("\n")
    end

    def render_group(node, context, width_pct = 100)
      items = node.element_children.select { |e| e.tag_name == "mj-column" }
      widths = compute_column_widths(items, context)
      items.each_with_index.map do |item, i|
        attrs = resolved_attributes(item, context)
        render_column(item, context, attrs, widths[i])
      end.join("\n")
    end

    def render_column(node, context, attrs, width_pct = 100)
      css_class = attrs["css-class"]
      pct_rounded = width_pct.to_f.round(4).to_s.sub(/\.?0+$/, "")
      context[:column_widths] << pct_rounded if context[:column_widths]
      col_class = "mj-column-per-#{pct_rounded} mj-outlook-group-fix"
      col_class = "#{col_class} #{css_class}" if css_class && !css_class.empty?

      col_style = style_join(
        "font-size" => "0px",
        "text-align" => "left",
        "direction" => "ltr",
        "display" => "inline-block",
        "vertical-align" => attrs["vertical-align"] || "top",
        "width" => "100%"
      )
      children = render_children(node, context, parent: "mj-column")

      %(<div class="#{escape_attr(col_class)}" style="#{col_style}"><table border="0" cellpadding="0" cellspacing="0" role="presentation" width="100%" style="width:100%;"><tbody>#{children}</tbody></table></div>)
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
        remaining = [100 - specified, 0].max
        each_unset = remaining / unset_count
        widths.map { |w| w || each_unset }
      else
        widths
      end
    end


    def render_spacer(attrs)
      css_class = attrs["css-class"]
      height = attrs["height"] || "20px"
      td_attrs = {"class" => css_class, "style" => "line-height:#{escape_attr(height)};font-size:0;"}
      %(<tr><td#{html_attrs(td_attrs)}>&nbsp;</td></tr>)
    end

    def render_hero(node, context, attrs)
      background = attrs["background-url"] ? "background-image:url('#{escape_attr(attrs["background-url"])}');background-size:cover;" : ""
      section = %(<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0"><tbody>#{render_children(node, context, parent: "mj-hero")}</tbody></table>)
      %(<tr><td style="padding:#{escape_attr(attrs["padding"] || "0")};#{background}">#{section}</td></tr>)
    end

    def render_social(node, context, attrs)
      align = attrs["align"] || "left"
      items = node.element_children.select { |child| child.tag_name == "mj-social-element" }
      content = items.map { |item| render_node(item, context, parent: "mj-social") }.join
      %(<tr><td style="padding:#{escape_attr(attrs["padding"] || "10px 25px")};text-align:#{escape_attr(align)};"><table role="presentation" cellspacing="0" cellpadding="0" border="0"><tbody><tr>#{content}</tr></tbody></table></td></tr>)
    end

    def render_social_element(node, attrs)
      href = escape_attr(attrs["href"] || "#")
      name = node.attributes["name"] || "social"
      label = node.text_content.strip
      label = name.capitalize if label.empty?
      %(<td style="padding-right:10px;"><a href="#{href}" style="text-decoration:none;color:#{escape_attr(attrs["color"] || "#000000")};">#{escape_html(label)}</a></td>)
    end

    def render_navbar(node, context, attrs)
      align = attrs["align"] || "center"
      links = node.element_children.select { |child| child.tag_name == "mj-navbar-link" }
      content = links.map { |child| render_node(child, context, parent: "mj-navbar") }.join
      %(<tr><td style="padding:#{escape_attr(attrs["padding"] || "10px 25px")};text-align:#{escape_attr(align)};"><table role="presentation" cellspacing="0" cellpadding="0" border="0"><tbody><tr>#{content}</tr></tbody></table></td></tr>)
    end

    def render_navbar_link(node, attrs, parent:)
      href = escape_attr(attrs["href"] || "#")
      label = node.text_content.strip
      style = style_join(
        "color" => attrs["color"] || "#000000",
        "font-family" => attrs["font-family"] || "Arial, sans-serif",
        "text-decoration" => "none",
        "padding" => attrs["padding"] || "0 10px"
      )
      content = %(<a href="#{href}" style="#{style}">#{escape_html(label)}</a>)
      return %(<td>#{content}</td>) if parent == "mj-navbar"

      content
    end

    def append_column_width_styles(context)
      widths = (context[:column_widths] || []).uniq.sort
      return if widths.empty?

      css = widths.map do |w|
        ".mj-column-per-#{w} { width:#{w}% !important; max-width: #{w}%; }"
      end.join("\n")
      context[:head_styles] << css
    end

    def append_component_head_styles(document, context)
      component_registry.each_value.uniq.each do |component|
        next unless component.respond_to?(:head_style)

        style = component.head_style
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
        register_component(registry, Components::Accordion.new(self))
        register_component(registry, Components::Button.new(self))
        register_component(registry, Components::Image.new(self))
        register_component(registry, Components::Text.new(self))
        register_component(registry, Components::Divider.new(self))
        register_component(registry, Components::Table.new(self))
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
      node_classes.each do |klass|
        attrs.merge!(context[:classes][klass] || {})
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
  end
end
