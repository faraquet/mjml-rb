require "cgi"

module MJML
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
      content = render_children(body, context, parent: "mj-body")
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

      <<~HTML
        <!doctype html>
        <html lang="en">
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>#{escape_html(title)}</title>
            #{font_links}
            <style type="text/css">#{head_styles}</style>
          </head>
          <body style="margin:0;padding:0;background:#ffffff;">
            #{preview_block}
            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
              <tbody>
                #{content}
              </tbody>
            </table>
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
      case node.tag_name
      when "mj-wrapper"
        %(<tr><td style="#{style_join("padding" => attrs["padding"] || "0")}">#{render_children(node, context, parent: "mj-wrapper")}</td></tr>)
      when "mj-section"
        %(<tr><td style="#{style_join(section_style(attrs))}">#{render_section(node, context)}</td></tr>)
      when "mj-group"
        render_group(node, context)
      when "mj-column"
        render_column(node, context)
      when "mj-text"
        render_text(node, attrs)
      when "mj-image"
        render_image(attrs)
      when "mj-button"
        render_button(node, attrs)
      when "mj-divider"
        render_divider(attrs)
      when "mj-spacer"
        render_spacer(attrs)
      when "mj-table"
        render_table(node, attrs)
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

    def render_section(node, context)
      columns = node.element_children.select { |e| %w[mj-column mj-group].include?(e.tag_name) }
      return render_children(node, context, parent: "mj-section") if columns.empty?

      cols = columns.map { |col| %(<td valign="top">#{render_node(col, context, parent: "mj-section")}</td>) }.join
      %(<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0"><tbody><tr>#{cols}</tr></tbody></table>)
    end

    def render_group(node, context)
      items = node.element_children.select { |e| e.tag_name == "mj-column" }
      cols = items.map { |item| %(<td valign="top">#{render_node(item, context, parent: "mj-group")}</td>) }.join
      %(<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0"><tbody><tr>#{cols}</tr></tbody></table>)
    end

    def render_column(node, context)
      %(<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0"><tbody>#{render_children(node, context, parent: "mj-column")}</tbody></table>)
    end

    def render_text(node, attrs)
      style = style_join(
        "font-family" => attrs["font-family"] || "Arial, sans-serif",
        "font-size" => attrs["font-size"] || "13px",
        "line-height" => attrs["line-height"] || "1.5",
        "color" => attrs["color"] || "#000000",
        "text-align" => attrs["align"],
        "padding" => attrs["padding"] || "10px 25px"
      )

      content = node.children.map { |child| child.text? ? escape_html(child.content.to_s) : raw_inner(child) }.join
      %(<tr><td style="#{style}">#{content}</td></tr>)
    end

    def render_image(attrs)
      style = style_join(
        "max-width" => "100%",
        "display" => "block",
        "border" => "0"
      )
      td_style = style_join("padding" => attrs["padding"] || "10px 25px", "text-align" => attrs["align"])
      src = escape_attr(attrs["src"])
      alt = escape_attr(attrs["alt"])
      width = attrs["width"] ? %( width="#{escape_attr(attrs["width"])}") : ""

      %(<tr><td style="#{td_style}"><img src="#{src}" alt="#{alt}" style="#{style}"#{width}></td></tr>)
    end

    def render_button(node, attrs)
      href = escape_attr(attrs["href"] || "#")
      td_style = style_join("padding" => attrs["padding"] || "10px 25px", "text-align" => attrs["align"])
      link_style = style_join(
        "display" => "inline-block",
        "padding" => attrs["inner-padding"] || "12px 24px",
        "background" => attrs["background-color"] || "#414141",
        "color" => attrs["color"] || "#ffffff",
        "text-decoration" => "none",
        "border-radius" => attrs["border-radius"] || "3px",
        "font-family" => attrs["font-family"] || "Arial, sans-serif"
      )
      label = escape_html(node.text_content.strip)
      %(<tr><td style="#{td_style}"><a href="#{href}" style="#{link_style}">#{label}</a></td></tr>)
    end

    def render_divider(attrs)
      border_width = attrs["border-width"] || "1px"
      border_style = attrs["border-style"] || "solid"
      border_color = attrs["border-color"] || "#000000"
      td_style = style_join("padding" => attrs["padding"] || "10px 25px")
      hr_style = style_join("border" => "0", "border-top" => "#{border_width} #{border_style} #{border_color}")
      %(<tr><td style="#{td_style}"><hr style="#{hr_style}"></td></tr>)
    end

    def render_spacer(attrs)
      height = attrs["height"] || "20px"
      %(<tr><td style="line-height:#{escape_attr(height)};font-size:0;">&nbsp;</td></tr>)
    end

    def render_table(node, attrs)
      td_style = style_join("padding" => attrs["padding"] || "10px 25px")
      raw = raw_inner(node)
      %(<tr><td style="#{td_style}"><table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">#{raw}</table></td></tr>)
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

    def section_style(attrs)
      {
        "padding" => attrs["padding"] || "20px 0",
        "background-color" => attrs["background-color"]
      }
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

    def escape_html(value)
      CGI.escapeHTML(value.to_s)
    end

    def escape_attr(value)
      CGI.escapeHTML(value.to_s)
    end
  end
end
