require_relative "base"

module MjmlRb
  module Components
    class Social < Base
      TAGS = %w[mj-social mj-social-element].freeze

      IMG_BASE_URL = "https://www.mailjet.com/images/theme/v1/icons/ico-social/".freeze

      SOCIAL_NETWORKS = {
        "facebook"  => { "share-url" => "https://www.facebook.com/sharer/sharer.php?u=[[URL]]",   "background-color" => "#3b5998", "src" => "#{IMG_BASE_URL}facebook.png" },
        "twitter"   => { "share-url" => "https://twitter.com/intent/tweet?url=[[URL]]",           "background-color" => "#55acee", "src" => "#{IMG_BASE_URL}twitter.png" },
        "x"         => { "share-url" => "https://twitter.com/intent/tweet?url=[[URL]]",           "background-color" => "#000000", "src" => "#{IMG_BASE_URL}twitter-x.png" },
        "google"    => { "share-url" => "https://plus.google.com/share?url=[[URL]]",              "background-color" => "#dc4e41", "src" => "#{IMG_BASE_URL}google-plus.png" },
        "pinterest" => { "share-url" => "https://pinterest.com/pin/create/button/?url=[[URL]]&media=&description=", "background-color" => "#bd081c", "src" => "#{IMG_BASE_URL}pinterest.png" },
        "linkedin"  => { "share-url" => "https://www.linkedin.com/shareArticle?mini=true&url=[[URL]]&title=&summary=&source=", "background-color" => "#0077b5", "src" => "#{IMG_BASE_URL}linkedin.png" },
        "instagram" => { "background-color" => "#3f729b", "src" => "#{IMG_BASE_URL}instagram.png" },
        "web"       => { "background-color" => "#4BADE9", "src" => "#{IMG_BASE_URL}web.png" },
        "snapchat"  => { "background-color" => "#FFFA54", "src" => "#{IMG_BASE_URL}snapchat.png" },
        "youtube"   => { "background-color" => "#EB3323", "src" => "#{IMG_BASE_URL}youtube.png" },
        "tumblr"    => { "share-url" => "https://www.tumblr.com/widgets/share/tool?canonicalUrl=[[URL]]", "background-color" => "#344356", "src" => "#{IMG_BASE_URL}tumblr.png" },
        "github"    => { "background-color" => "#000000", "src" => "#{IMG_BASE_URL}github.png" },
        "xing"      => { "share-url" => "https://www.xing.com/app/user?op=share&url=[[URL]]",     "background-color" => "#296366", "src" => "#{IMG_BASE_URL}xing.png" },
        "vimeo"     => { "background-color" => "#53B4E7", "src" => "#{IMG_BASE_URL}vimeo.png" },
        "medium"    => { "background-color" => "#000000", "src" => "#{IMG_BASE_URL}medium.png" },
        "soundcloud" => { "background-color" => "#EF7F31", "src" => "#{IMG_BASE_URL}soundcloud.png" },
        "dribbble"  => { "background-color" => "#D95988", "src" => "#{IMG_BASE_URL}dribbble.png" }
      }.tap do |networks|
        # Build -noshare variants (share-url becomes [[URL]] i.e. pass-through)
        networks.keys.each do |key|
          networks["#{key}-noshare"] = networks[key].merge("share-url" => "[[URL]]")
        end
      end.freeze

      SOCIAL_ALLOWED_ATTRIBUTES = {
        "align" => "enum(left,right,center)",
        "border-radius" => "unit(px,%)",
        "container-background-color" => "color",
        "color" => "color",
        "font-family" => "string",
        "font-size" => "unit(px)",
        "font-style" => "string",
        "font-weight" => "string",
        "icon-size" => "unit(px,%)",
        "icon-height" => "unit(px,%)",
        "icon-padding" => "unit(px,%){1,4}",
        "inner-padding" => "unit(px,%){1,4}",
        "line-height" => "unit(px,%,)",
        "mode" => "enum(horizontal,vertical)",
        "padding-bottom" => "unit(px,%)",
        "padding-left" => "unit(px,%)",
        "padding-right" => "unit(px,%)",
        "padding-top" => "unit(px,%)",
        "padding" => "unit(px,%){1,4}",
        "table-layout" => "enum(auto,fixed)",
        "text-padding" => "unit(px,%){1,4}",
        "text-decoration" => "string",
        "vertical-align" => "enum(top,bottom,middle)"
      }.freeze

      SOCIAL_ELEMENT_ALLOWED_ATTRIBUTES = {
        "align" => "enum(left,center,right)",
        "icon-position" => "enum(left,right)",
        "background-color" => "color",
        "color" => "color",
        "border-radius" => "unit(px)",
        "font-family" => "string",
        "font-size" => "unit(px)",
        "font-style" => "string",
        "font-weight" => "string",
        "href" => "string",
        "icon-size" => "unit(px,%)",
        "icon-height" => "unit(px,%)",
        "icon-padding" => "unit(px,%){1,4}",
        "line-height" => "unit(px,%,)",
        "name" => "string",
        "padding-bottom" => "unit(px,%)",
        "padding-left" => "unit(px,%)",
        "padding-right" => "unit(px,%)",
        "padding-top" => "unit(px,%)",
        "padding" => "unit(px,%){1,4}",
        "text-padding" => "unit(px,%){1,4}",
        "rel" => "string",
        "src" => "string",
        "srcset" => "string",
        "sizes" => "string",
        "alt" => "string",
        "title" => "string",
        "target" => "string",
        "text-decoration" => "string",
        "vertical-align" => "enum(top,middle,bottom)"
      }.freeze

      class << self
        def allowed_attributes_for(tag_name)
          tag_name == "mj-social-element" ? SOCIAL_ELEMENT_ALLOWED_ATTRIBUTES : SOCIAL_ALLOWED_ATTRIBUTES
        end

        def allowed_attributes
          SOCIAL_ALLOWED_ATTRIBUTES
        end
      end

      # Attributes Social parent passes down to its mj-social-element children
      INHERITED_ATTRS = %w[
        border-radius color font-family font-size font-weight font-style
        icon-size icon-height icon-padding text-padding line-height text-decoration
      ].freeze

      SOCIAL_DEFAULT_ATTRIBUTES = {
        "align"           => "center",
        "border-radius"   => "3px",
        "color"           => "#333333",
        "font-family"     => "Ubuntu, Helvetica, Arial, sans-serif",
        "font-size"       => "13px",
        "icon-size"       => "20px",
        "line-height"     => "22px",
        "mode"            => "horizontal",
        "padding"         => "10px 25px",
        "text-decoration" => "none"
      }.freeze

      ELEMENT_DEFAULT_ATTRIBUTES = {
        "alt"             => "",
        "align"           => "left",
        "icon-position"   => "left",
        "color"           => "#000",
        "border-radius"   => "3px",
        "font-family"     => "Ubuntu, Helvetica, Arial, sans-serif",
        "font-size"       => "13px",
        "line-height"     => "1",
        "padding"         => "4px",
        "text-padding"    => "4px 4px 4px 0",
        "target"          => "_blank",
        "text-decoration" => "none",
        "vertical-align"  => "middle"
      }.freeze

      def render(tag_name:, node:, context:, attrs:, parent:)
        case tag_name
        when "mj-social"
          render_social(node, context, attrs)
        when "mj-social-element"
          # Direct dispatch (no parent attrs merging) — fallback for standalone use
          render_social_element(node, ELEMENT_DEFAULT_ATTRIBUTES.merge(attrs))
        end
      end

      private

      # ── mj-social ──────────────────────────────────────────────────────────

      def render_social(node, context, attrs)
        a = SOCIAL_DEFAULT_ATTRIBUTES.merge(attrs)

        outer_td_style = style_join(
          "background"     => a["container-background-color"],
          "font-size"      => "0px",
          "padding"        => a["padding"],
          "padding-top"    => a["padding-top"],
          "padding-right"  => a["padding-right"],
          "padding-bottom" => a["padding-bottom"],
          "padding-left"   => a["padding-left"],
          "word-break"     => "break-word"
        )
        outer_td_attrs = {
          "align"          => a["align"],
          "vertical-align" => a["vertical-align"],
          "class"          => a["css-class"],
          "style"          => outer_td_style
        }

        mode = a["mode"] == "vertical" ? "vertical" : "horizontal"
        inner = if mode == "vertical"
                  render_vertical(node, context, a)
                else
                  render_horizontal(node, context, a)
                end

        %(<tr><td#{html_attrs(outer_td_attrs)}>#{inner}</td></tr>)
      end

      def social_element_children(node)
        node.element_children.select { |c| c.tag_name == "mj-social-element" }
      end

      # Compute the attributes Social passes down to its children
      def inherited_attrs(social_attrs)
        base = {}
        base["padding"] = social_attrs["inner-padding"] if social_attrs["inner-padding"]

        INHERITED_ATTRS.each_with_object(base) do |attr, h|
          val = social_attrs[attr]
          h[attr] = val unless val.nil?
        end
      end

      def render_horizontal(node, context, social_attrs)
        align     = social_attrs["align"]
        inherited = inherited_attrs(social_attrs)
        elements  = social_element_children(node)
        return "" if elements.empty?

        outlook_open  = %(<!--[if mso | IE]><table align="#{escape_attr(align)}" border="0" cellpadding="0" cellspacing="0" role="presentation" ><tr>)
        outlook_close = %(</tr></table><![endif]-->)

        children_html = with_inherited_mj_class(context, node) do
          elements.map.with_index do |child, idx|
            child_attrs  = resolved_attributes(child, context)
            merged_attrs = ELEMENT_DEFAULT_ATTRIBUTES.merge(inherited).merge(child_attrs)
            el_html      = render_social_element(child, merged_attrs)

            outlook_td_open  = idx == 0 ? "<td>" : "</td><td>"
            %(#{outlook_td_open}<![endif]--><table align="#{escape_attr(align)}" border="0" cellpadding="0" cellspacing="0" role="presentation" style="float:none;display:inline-table;"><tbody>#{el_html}</tbody></table><!--[if mso | IE]>)
          end.join
        end

        %(#{outlook_open}#{children_html}</td>#{outlook_close})
      end

      def render_vertical(node, context, social_attrs)
        inherited = inherited_attrs(social_attrs)
        elements  = social_element_children(node)

        children_html = with_inherited_mj_class(context, node) do
          elements.map do |child|
            child_attrs  = resolved_attributes(child, context)
            merged_attrs = ELEMENT_DEFAULT_ATTRIBUTES.merge(inherited).merge(child_attrs)
            render_social_element(child, merged_attrs)
          end.join
        end

        %(<table border="0" cellpadding="0" cellspacing="0" role="presentation" style="margin:0px;"><tbody>#{children_html}</tbody></table>)
      end

      # ── mj-social-element ──────────────────────────────────────────────────

      def render_social_element(node, attrs)
        a        = attrs # already merged with defaults by caller
        net_name = node["name"]
        network  = SOCIAL_NETWORKS[net_name] || {}

        # Resolve href: if network has a share-url, substitute [[URL]] with the raw href
        raw_href    = a["href"]
        share_url   = network["share-url"]
        final_href  = if raw_href && share_url
                        share_url.gsub("[[URL]]", raw_href)
                      else
                        raw_href
                      end
        has_link = !raw_href.nil?

        # Resolve icon attrs (element overrides network defaults)
        icon_size   = a["icon-size"]  || network["icon-size"]
        icon_height = a["icon-height"] || network["icon-height"]
        bg_color    = a["background-color"] || network["background-color"]
        src         = a["src"] || network["src"]
        srcset      = a["srcset"] || network["srcset"]
        sizes_attr  = a["sizes"]  || network["sizes"]
        icon_width  = icon_size ? icon_size.to_i.to_s : nil

        border_radius  = a["border-radius"]
        icon_position  = a["icon-position"] || "left"
        padding        = a["padding"]
        text_padding   = a["text-padding"]
        vertical_align = a["vertical-align"]
        align_val      = a["align"]
        alt_val        = a["alt"] || ""
        target_val     = a["target"]
        rel_val        = a["rel"]
        title_val      = a["title"]
        icon_padding   = a["icon-padding"]
        icon_h         = icon_height || icon_size

        td_style = style_join(
          "padding"        => padding,
          "padding-top"    => a["padding-top"],
          "padding-right"  => a["padding-right"],
          "padding-bottom" => a["padding-bottom"],
          "padding-left"   => a["padding-left"],
          "vertical-align" => vertical_align
        )

        inner_table_style = style_join(
          "background"    => bg_color,
          "border-radius" => border_radius,
          "width"         => icon_size
        )

        icon_td_style = style_join(
          "padding"        => icon_padding,
          "font-size"      => "0",
          "height"         => icon_h,
          "vertical-align" => "middle",
          "width"          => icon_size
        )

        img_style = style_join(
          "border-radius" => border_radius,
          "display"       => "block"
        )

        img_attrs = {
          "alt" => alt_val,
          "title" => title_val,
          "src" => src,
          "style" => img_style.empty? ? nil : img_style,
          "width" => icon_width,
          "sizes" => sizes_attr,
          "srcset" => srcset
        }
        img_tag = "<img#{html_attrs(img_attrs)} />"

        if has_link
          link_attrs_str = html_attrs({ "href" => final_href, "rel" => rel_val, "target" => target_val })
          icon_content = %(<a#{link_attrs_str}>#{img_tag}</a>)
        else
          icon_content = img_tag
        end

        icon_td = %(<td style="#{icon_td_style}">#{icon_content}</td>)

        icon_cell = <<~HTML.strip
          <td style="#{td_style}"><table border="0" cellpadding="0" cellspacing="0" role="presentation" style="#{inner_table_style}"><tbody><tr>#{icon_td}</tr></tbody></table></td>
        HTML

        # Content cell (text)
        content = node.content.strip
        content_cell = if content.empty?
                         ""
                       else
                         td_text_style = style_join(
                           "vertical-align" => "middle",
                           "padding"        => text_padding,
                           "text-align"     => align_val
                         )
                         text_style = style_join(
                           "color"           => a["color"],
                           "font-size"       => a["font-size"],
                           "font-weight"     => a["font-weight"],
                           "font-style"      => a["font-style"],
                           "font-family"     => a["font-family"],
                           "line-height"     => a["line-height"],
                           "text-decoration" => a["text-decoration"]
                         )

                         inner_text = " #{escape_html(content)} "
                         text_elem = if has_link
                                       link_attrs_str = html_attrs({ "href" => final_href, "style" => text_style, "rel" => rel_val, "target" => target_val })
                                       %(<a#{link_attrs_str}>#{inner_text}</a>)
                                     else
                                       %(<span style="#{text_style}">#{inner_text}</span>)
                                     end
                         %(<td style="#{td_text_style}">#{text_elem}</td>)
                       end

        cells = icon_position == "right" ? "#{content_cell} #{icon_cell}" : "#{icon_cell} #{content_cell}"
        css_class = a["css-class"]
        tr_class  = css_class ? %( class="#{escape_attr(css_class)}") : ""

        %(<tr#{tr_class}>#{cells}</tr>)
      end

    end
  end
end
