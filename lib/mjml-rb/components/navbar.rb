require "securerandom"

require_relative "base"

module MjmlRb
  module Components
    class Navbar < Base
      TAGS = %w[mj-navbar mj-navbar-link].freeze

      NAVBAR_ALLOWED_ATTRIBUTES = {
        "align" => "enum(left,center,right)",
        "base-url" => "string",
        "hamburger" => "string",
        "ico-align" => "enum(left,center,right)",
        "ico-open" => "string",
        "ico-close" => "string",
        "ico-color" => "color",
        "ico-font-size" => "unit(px,%)",
        "ico-font-family" => "string",
        "ico-text-transform" => "string",
        "ico-padding" => "unit(px,%){1,4}",
        "ico-padding-left" => "unit(px,%)",
        "ico-padding-top" => "unit(px,%)",
        "ico-padding-right" => "unit(px,%)",
        "ico-padding-bottom" => "unit(px,%)",
        "padding" => "unit(px,%){1,4}",
        "padding-left" => "unit(px,%)",
        "padding-top" => "unit(px,%)",
        "padding-right" => "unit(px,%)",
        "padding-bottom" => "unit(px,%)",
        "ico-text-decoration" => "string",
        "ico-line-height" => "unit(px,%)"
      }.freeze

      NAVBAR_LINK_ALLOWED_ATTRIBUTES = {
        "color" => "color",
        "font-family" => "string",
        "font-size" => "unit(px)",
        "font-style" => "string",
        "font-weight" => "string",
        "href" => "string",
        "name" => "string",
        "target" => "string",
        "rel" => "string",
        "letter-spacing" => "string",
        "line-height" => "unit(px,%)",
        "padding-bottom" => "unit(px,%)",
        "padding-left" => "unit(px,%)",
        "padding-right" => "unit(px,%)",
        "padding-top" => "unit(px,%)",
        "padding" => "unit(px,%){1,4}",
        "text-decoration" => "string",
        "text-transform" => "string"
      }.freeze

      NAVBAR_DEFAULT_ATTRIBUTES = {
        "align" => "center",
        "base-url" => nil,
        "hamburger" => nil,
        "ico-align" => "center",
        "ico-open" => "&#9776;",
        "ico-close" => "&#8855;",
        "ico-color" => "#000000",
        "ico-font-size" => "30px",
        "ico-font-family" => "Ubuntu, Helvetica, Arial, sans-serif",
        "ico-text-transform" => "uppercase",
        "ico-padding" => "10px",
        "ico-text-decoration" => "none",
        "ico-line-height" => "30px"
      }.freeze

      NAVBAR_LINK_DEFAULT_ATTRIBUTES = {
        "color" => "#000000",
        "font-family" => "Ubuntu, Helvetica, Arial, sans-serif",
        "font-size" => "13px",
        "font-weight" => "normal",
        "line-height" => "22px",
        "padding" => "15px 10px",
        "target" => "_blank",
        "text-decoration" => "none",
        "text-transform" => "uppercase"
      }.freeze

      class << self
        def allowed_attributes_for(tag_name)
          tag_name == "mj-navbar-link" ? NAVBAR_LINK_ALLOWED_ATTRIBUTES : NAVBAR_ALLOWED_ATTRIBUTES
        end

        def allowed_attributes
          NAVBAR_ALLOWED_ATTRIBUTES
        end
      end

      def tags
        TAGS
      end

      def head_style(breakpoint)
        lower_breakpoint = make_lower_breakpoint(breakpoint)

        <<~CSS
          noinput.mj-menu-checkbox { display:block!important; max-height:none!important; visibility:visible!important; }

          @media only screen and (max-width:#{lower_breakpoint}) {
            .mj-menu-checkbox[type="checkbox"] ~ .mj-inline-links { display:none!important; }
            .mj-menu-checkbox[type="checkbox"]:checked ~ .mj-inline-links,
            .mj-menu-checkbox[type="checkbox"] ~ .mj-menu-trigger { display:block!important; max-width:none!important; max-height:none!important; font-size:inherit!important; }
            .mj-menu-checkbox[type="checkbox"] ~ .mj-inline-links > a { display:block!important; }
            .mj-menu-checkbox[type="checkbox"]:checked ~ .mj-menu-trigger .mj-menu-icon-close { display:block!important; }
            .mj-menu-checkbox[type="checkbox"]:checked ~ .mj-menu-trigger .mj-menu-icon-open { display:none!important; }
          }
        CSS
      end

      def head_style_tags
        ["mj-navbar"]
      end

      def render(tag_name:, node:, context:, attrs:, parent:)
        case tag_name
        when "mj-navbar"
          render_navbar(node, context, attrs)
        when "mj-navbar-link"
          render_navbar_link(node, context, attrs, parent: parent)
        end
      end

      private

      def render_navbar(node, context, attrs)
        a = NAVBAR_DEFAULT_ATTRIBUTES.merge(attrs)
        align = a["align"]

        outer_td_style = style_join(
          "font-size" => "0px",
          "padding" => a["padding"],
          "padding-top" => a["padding-top"],
          "padding-right" => a["padding-right"],
          "padding-bottom" => a["padding-bottom"],
          "padding-left" => a["padding-left"],
          "text-align" => align,
          "word-break" => "break-word"
        )
        outer_td_attrs = {
          "align" => align,
          "class" => a["css-class"],
          "style" => outer_td_style
        }

        previous_base_url = context[:navbar_base_url]
        context[:navbar_base_url] = a["base-url"]

        inner = +""
        inner << render_hamburger(a) if a["hamburger"] == "hamburger"
        inner << %(<div class="mj-inline-links" style="width:100%;text-align:#{escape_attr(align)};">)
        inner << %(<!--[if mso | IE]><table role="presentation" border="0" cellpadding="0" cellspacing="0" align="#{escape_attr(align)}"><tr><![endif]-->)
        inner << render_navbar_children(node, context)
        inner << %(<!--[if mso | IE]></tr></table><![endif]-->)
        inner << %(</div>)

        %(<tr><td#{html_attrs(outer_td_attrs)}>#{inner}</td></tr>)
      ensure
        context[:navbar_base_url] = previous_base_url
      end

      def render_navbar_children(node, context)
        with_inherited_mj_class(context, node) do
          node.element_children.map do |child|
            case child.tag_name
            when "mj-navbar-link", "mj-raw"
              render_node(child, context, parent: "mj-navbar")
            else
              ""
            end
          end.join
        end
      end

      def render_navbar_link(node, context, attrs, parent:)
        a = NAVBAR_LINK_DEFAULT_ATTRIBUTES.merge(attrs)
        href = joined_href(a["href"], context[:navbar_base_url])
        css_class = a["css-class"]
        anchor_class = ["mj-link", css_class].compact.join(" ")
        td_class = suffix_css_classes(css_class, "outlook")

        anchor_style = style_join(
          "display" => "inline-block",
          "color" => a["color"],
          "font-family" => a["font-family"],
          "font-size" => a["font-size"],
          "font-style" => a["font-style"],
          "font-weight" => a["font-weight"],
          "letter-spacing" => a["letter-spacing"],
          "line-height" => a["line-height"],
          "text-decoration" => a["text-decoration"],
          "text-transform" => a["text-transform"],
          "padding" => a["padding"],
          "padding-top" => a["padding-top"],
          "padding-left" => a["padding-left"],
          "padding-right" => a["padding-right"],
          "padding-bottom" => a["padding-bottom"]
        )
        link_attrs = {
          "class" => anchor_class,
          "href" => href,
          "rel" => a["rel"],
          "target" => a["target"],
          "name" => a["name"],
          "style" => anchor_style
        }

        content = raw_inner(node)
        link = %(<a#{html_attrs(link_attrs)}>#{content}</a>)
        return link unless parent == "mj-navbar"

        td_style = style_join(
          "padding" => a["padding"],
          "padding-top" => a["padding-top"],
          "padding-left" => a["padding-left"],
          "padding-right" => a["padding-right"],
          "padding-bottom" => a["padding-bottom"]
        )

        %(<!--[if mso | IE]><td#{html_attrs("class" => td_class, "style" => td_style)}><![endif]-->#{link}<!--[if mso | IE]></td><![endif]-->)
      end

      def render_hamburger(attrs)
        label_key = SecureRandom.hex(8)
        trigger_style = style_join(
          "display" => "none",
          "max-height" => "0px",
          "max-width" => "0px",
          "font-size" => "0px",
          "overflow" => "hidden"
        )
        label_style = style_join(
          "display" => "block",
          "cursor" => "pointer",
          "mso-hide" => "all",
          "-moz-user-select" => "none",
          "user-select" => "none",
          "color" => attrs["ico-color"],
          "font-size" => attrs["ico-font-size"],
          "font-family" => attrs["ico-font-family"],
          "text-transform" => attrs["ico-text-transform"],
          "text-decoration" => attrs["ico-text-decoration"],
          "line-height" => attrs["ico-line-height"],
          "padding" => attrs["ico-padding"],
          "padding-top" => attrs["ico-padding-top"],
          "padding-right" => attrs["ico-padding-right"],
          "padding-bottom" => attrs["ico-padding-bottom"],
          "padding-left" => attrs["ico-padding-left"]
        )

        checkbox = %(<!--[if !mso]><!--><input type="checkbox" id="#{escape_attr(label_key)}" class="mj-menu-checkbox" style="display:none !important; max-height:0; visibility:hidden;" /><!--<![endif]-->)
        trigger = %(<div class="mj-menu-trigger" style="#{trigger_style}"><label for="#{escape_attr(label_key)}" class="mj-menu-label" align="#{escape_attr(attrs["ico-align"])}" style="#{label_style}"><span class="mj-menu-icon-open" style="mso-hide:all;">#{attrs["ico-open"]}</span><span class="mj-menu-icon-close" style="display:none;mso-hide:all;">#{attrs["ico-close"]}</span></label></div>)

        "#{checkbox}#{trigger}"
      end

      def joined_href(href, base_url)
        return href if href.nil? || href.empty? || base_url.nil? || base_url.empty?

        "#{base_url}#{href}"
      end

      def suffix_css_classes(classes, suffix)
        return nil if classes.nil? || classes.empty?

        classes.split(/\s+/).map { |klass| "#{klass}-#{suffix}" }.join(" ")
      end

      def make_lower_breakpoint(breakpoint)
        pixels = breakpoint.to_s[/\d+/]
        return breakpoint if pixels.nil?

        "#{pixels.to_i - 1}px"
      end
    end
  end
end
