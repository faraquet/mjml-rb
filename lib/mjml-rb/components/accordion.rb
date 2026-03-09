require_relative "base"

module MjmlRb
  module Components
    class Accordion < Base
      TAGS = %w[
        mj-accordion
        mj-accordion-element
        mj-accordion-title
        mj-accordion-text
      ].freeze

      ACCORDION_ALLOWED_ATTRIBUTES = {
        "container-background-color" => "color",
        "border" => "string",
        "font-family" => "string",
        "icon-align" => "enum(top,middle,bottom)",
        "icon-width" => "unit(px,%)",
        "icon-height" => "unit(px,%)",
        "icon-wrapped-url" => "string",
        "icon-wrapped-alt" => "string",
        "icon-unwrapped-url" => "string",
        "icon-unwrapped-alt" => "string",
        "icon-position" => "enum(left,right)",
        "padding-bottom" => "unit(px,%)",
        "padding-left" => "unit(px,%)",
        "padding-right" => "unit(px,%)",
        "padding-top" => "unit(px,%)",
        "padding" => "unit(px,%){1,4}"
      }.freeze

      ACCORDION_ELEMENT_ALLOWED_ATTRIBUTES = {
        "background-color" => "color",
        "border" => "string",
        "font-family" => "string",
        "icon-align" => "enum(top,middle,bottom)",
        "icon-width" => "unit(px,%)",
        "icon-height" => "unit(px,%)",
        "icon-wrapped-url" => "string",
        "icon-wrapped-alt" => "string",
        "icon-unwrapped-url" => "string",
        "icon-unwrapped-alt" => "string",
        "icon-position" => "enum(left,right)"
      }.freeze

      ACCORDION_TITLE_ALLOWED_ATTRIBUTES = {
        "background-color" => "color",
        "color" => "color",
        "font-size" => "unit(px)",
        "font-family" => "string",
        "font-weight" => "string",
        "padding-bottom" => "unit(px,%)",
        "padding-left" => "unit(px,%)",
        "padding-right" => "unit(px,%)",
        "padding-top" => "unit(px,%)",
        "padding" => "unit(px,%){1,4}"
      }.freeze

      ACCORDION_TEXT_ALLOWED_ATTRIBUTES = {
        "background-color" => "color",
        "font-size" => "unit(px)",
        "font-family" => "string",
        "font-weight" => "string",
        "letter-spacing" => "unit(px,em)",
        "line-height" => "unit(px,%,)",
        "color" => "color",
        "padding-bottom" => "unit(px,%)",
        "padding-left" => "unit(px,%)",
        "padding-right" => "unit(px,%)",
        "padding-top" => "unit(px,%)",
        "padding" => "unit(px,%){1,4}"
      }.freeze

      class << self
        def allowed_attributes_for(tag_name)
          case tag_name
          when "mj-accordion"         then ACCORDION_ALLOWED_ATTRIBUTES
          when "mj-accordion-element" then ACCORDION_ELEMENT_ALLOWED_ATTRIBUTES
          when "mj-accordion-title"   then ACCORDION_TITLE_ALLOWED_ATTRIBUTES
          when "mj-accordion-text"    then ACCORDION_TEXT_ALLOWED_ATTRIBUTES
          else {}
          end
        end

        def allowed_attributes
          ACCORDION_ALLOWED_ATTRIBUTES
        end
      end

      HEAD_STYLE = <<~CSS.freeze
        noinput.mj-accordion-checkbox { display:block!important; }
        @media yahoo, only screen and (min-width:0) {
          .mj-accordion-element { display:block; }
          input.mj-accordion-checkbox, .mj-accordion-less { display:none!important; }
          input.mj-accordion-checkbox + * .mj-accordion-title { cursor:pointer; touch-action:manipulation; -webkit-user-select:none; -moz-user-select:none; user-select:none; }
          input.mj-accordion-checkbox + * .mj-accordion-content { overflow:hidden; display:none; }
          input.mj-accordion-checkbox + * .mj-accordion-more { display:block!important; }
          input.mj-accordion-checkbox:checked + * .mj-accordion-content { display:block; }
          input.mj-accordion-checkbox:checked + * .mj-accordion-more { display:none!important; }
          input.mj-accordion-checkbox:checked + * .mj-accordion-less { display:block!important; }
        }
        .moz-text-html input.mj-accordion-checkbox + * .mj-accordion-title { cursor:auto; touch-action:auto; -webkit-user-select:auto; -moz-user-select:auto; user-select:auto; }
        .moz-text-html input.mj-accordion-checkbox + * .mj-accordion-content { overflow:hidden; display:block; }
        .moz-text-html input.mj-accordion-checkbox + * .mj-accordion-ico { display:none; }
      CSS

      DEFAULTS = {
        "border" => "2px solid black",
        "font-family" => "Ubuntu, Helvetica, Arial, sans-serif",
        "icon-align" => "middle",
        "icon-wrapped-url" => "https://i.imgur.com/bIXv1bk.png",
        "icon-wrapped-alt" => "+",
        "icon-unwrapped-url" => "https://i.imgur.com/w4uTygT.png",
        "icon-unwrapped-alt" => "-",
        "icon-position" => "right",
        "icon-height" => "32px",
        "icon-width" => "32px",
        "padding" => "10px 25px"
      }.freeze

      TITLE_DEFAULTS = {
        "font-size" => "13px",
        "padding" => "16px"
      }.freeze

      TEXT_DEFAULTS = {
        "font-size" => "13px",
        "line-height" => "1",
        "padding" => "16px"
      }.freeze

      def tags
        TAGS
      end

      def head_style
        HEAD_STYLE
      end

      def head_style_tags
        ["mj-accordion"]
      end

      def render(tag_name:, node:, context:, attrs:, parent:)
        case tag_name
        when "mj-accordion"
          render_accordion(node, context, attrs)
        when "mj-accordion-element"
          render_accordion_element(node, context, DEFAULTS.merge(attrs))
        when "mj-accordion-title"
          render_accordion_title(node, DEFAULTS.merge(attrs))
        when "mj-accordion-text"
          render_accordion_text(node, DEFAULTS.merge(attrs))
        else
          render_children(node, context, parent: parent)
        end
      end

      private

      def render_accordion(node, context, attrs)
        accordion_attrs = DEFAULTS.merge(attrs)
        outer_style = style_join(
          "padding" => accordion_attrs["padding"],
          "background-color" => accordion_attrs["container-background-color"]
        )
        table_style = style_join(
          "width" => "100%",
          "border-collapse" => "collapse",
          "border" => accordion_attrs["border"],
          "border-bottom" => "none",
          "font-family" => accordion_attrs["font-family"]
        )
        inner = with_inherited_mj_class(context, node) do
          node.element_children.map do |child|
            case child.tag_name
            when "mj-accordion-element"
              render_accordion_element(child, context, accordion_attrs)
            when "mj-raw"
              raw_inner(child)
            else
              render_node(child, context, parent: "mj-accordion")
            end
          end.join
        end

        %(<tr><td style="#{outer_style}"><table role="presentation" width="100%" cellspacing="0" cellpadding="0" class="mj-accordion" style="#{table_style}"><tbody>#{inner}</tbody></table></td></tr>)
      end

      def render_accordion_element(node, context, parent_attrs)
        attrs = parent_attrs.merge(resolved_attributes(node, context))
        td_style = style_join(
          "padding" => "0px",
          "background-color" => attrs["background-color"]
        )
        label_style = style_join(
          "font-size" => "13px",
          "font-family" => attrs["font-family"] || parent_attrs["font-family"]
        )

        children = node.element_children
        has_title = children.any? { |child| child.tag_name == "mj-accordion-title" }
        has_text = children.any? { |child| child.tag_name == "mj-accordion-text" }
        content = []
        content << render_accordion_title(nil, attrs) unless has_title

        with_inherited_mj_class(context, node) do
          children.each do |child|
            case child.tag_name
            when "mj-accordion-title"
              child_attrs = attrs.merge(resolved_attributes(child, context))
              content << render_accordion_title(child, child_attrs)
            when "mj-accordion-text"
              child_attrs = attrs.merge(resolved_attributes(child, context))
              content << render_accordion_text(child, child_attrs)
            when "mj-raw"
              content << raw_inner(child)
            end
          end
        end
        content << render_accordion_text(nil, attrs) unless has_text

        css_class = attrs["css-class"] ? %( class="#{escape_attr(attrs["css-class"])}") : ""
        %(<tr#{css_class}><td style="#{td_style}"><label class="mj-accordion-element" style="#{label_style}"><input class="mj-accordion-checkbox" type="checkbox" style="display:none;" /><div>#{content.join("\n")}</div></label></td></tr>)
      end

      def render_accordion_title(node, attrs)
        title_attrs = TITLE_DEFAULTS.merge(attrs)
        td_style = style_join(
          "width" => "100%",
          "background-color" => title_attrs["background-color"],
          "color" => title_attrs["color"],
          "font-size" => title_attrs["font-size"],
          "font-family" => title_attrs["font-family"] || DEFAULTS["font-family"],
          "font-weight" => title_attrs["font-weight"],
          "padding" => title_attrs["padding"],
          "padding-bottom" => title_attrs["padding-bottom"],
          "padding-left" => title_attrs["padding-left"],
          "padding-right" => title_attrs["padding-right"],
          "padding-top" => title_attrs["padding-top"]
        )
        td2_style = style_join(
          "padding" => "16px",
          "background" => title_attrs["background-color"],
          "vertical-align" => title_attrs["icon-align"] || "middle"
        )
        icon_style = style_join(
          "display" => "none",
          "width" => title_attrs["icon-width"] || DEFAULTS["icon-width"],
          "height" => title_attrs["icon-height"] || DEFAULTS["icon-height"]
        )
        table_style = style_join(
          "width" => "100%",
          "border-bottom" => title_attrs["border"] || DEFAULTS["border"]
        )
        title_content = node ? raw_inner(node) : ""
        title_cell = %(<td style="#{td_style}">#{title_content}</td>)
        icon_cell = %(<td class="mj-accordion-ico" style="#{td2_style}"><img src="#{escape_attr(title_attrs["icon-wrapped-url"] || DEFAULTS["icon-wrapped-url"])}" alt="#{escape_attr(title_attrs["icon-wrapped-alt"] || DEFAULTS["icon-wrapped-alt"])}" class="mj-accordion-more" style="#{icon_style}" /><img src="#{escape_attr(title_attrs["icon-unwrapped-url"] || DEFAULTS["icon-unwrapped-url"])}" alt="#{escape_attr(title_attrs["icon-unwrapped-alt"] || DEFAULTS["icon-unwrapped-alt"])}" class="mj-accordion-less" style="#{icon_style}" /></td>)
        cells = title_attrs["icon-position"] == "left" ? "#{icon_cell}#{title_cell}" : "#{title_cell}#{icon_cell}"

        %(<div class="mj-accordion-title"><table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="#{table_style}"><tbody><tr>#{cells}</tr></tbody></table></div>)
      end

      def render_accordion_text(node, attrs)
        text_attrs = TEXT_DEFAULTS.merge(attrs)
        td_style = style_join(
          "background" => text_attrs["background-color"],
          "font-size" => text_attrs["font-size"],
          "font-family" => text_attrs["font-family"] || DEFAULTS["font-family"],
          "font-weight" => text_attrs["font-weight"],
          "letter-spacing" => text_attrs["letter-spacing"],
          "line-height" => text_attrs["line-height"],
          "color" => text_attrs["color"],
          "padding" => text_attrs["padding"],
          "padding-bottom" => text_attrs["padding-bottom"],
          "padding-left" => text_attrs["padding-left"],
          "padding-right" => text_attrs["padding-right"],
          "padding-top" => text_attrs["padding-top"]
        )
        table_style = style_join(
          "width" => "100%",
          "border-bottom" => text_attrs["border"] || DEFAULTS["border"]
        )
        content = node ? raw_inner(node) : ""
        css_class = text_attrs["css-class"] ? %( class="#{escape_attr(text_attrs["css-class"])}") : ""

        %(<div class="mj-accordion-content"><table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="#{table_style}"><tbody><tr><td#{css_class} style="#{td_style}">#{content}</td></tr></tbody></table></div>)
      end
    end
  end
end
