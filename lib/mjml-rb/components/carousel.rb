require "securerandom"

require_relative "base"

module MjmlRb
  module Components
    class Carousel < Base
      TAGS = ["mj-carousel"].freeze

      ALLOWED_ATTRIBUTES = {
        "align" => "enum(left,center,right)",
        "border-radius" => "unit(px,%){1,4}",
        "container-background-color" => "color",
        "icon-width" => "unit(px,%)",
        "left-icon" => "string",
        "padding" => "unit(px,%){1,4}",
        "padding-top" => "unit(px,%)",
        "padding-bottom" => "unit(px,%)",
        "padding-left" => "unit(px,%)",
        "padding-right" => "unit(px,%)",
        "right-icon" => "string",
        "thumbnails" => "enum(visible,hidden,supported)",
        "tb-border" => "string",
        "tb-border-radius" => "unit(px,%)",
        "tb-hover-border-color" => "color",
        "tb-selected-border-color" => "color",
        "tb-width" => "unit(px,%)"
      }.freeze

      DEFAULT_ATTRIBUTES = {
        "align" => "center",
        "border-radius" => "6px",
        "icon-width" => "44px",
        "left-icon" => "https://i.imgur.com/xTh3hln.png",
        "right-icon" => "https://i.imgur.com/os7o9kz.png",
        "thumbnails" => "visible",
        "tb-border" => "2px solid transparent",
        "tb-border-radius" => "6px",
        "tb-hover-border-color" => "#fead0d",
        "tb-selected-border-color" => "#ccc"
      }.freeze

      def render(tag_name:, node:, context:, attrs:, parent:)
        a = DEFAULT_ATTRIBUTES.merge(attrs)
        children = carousel_images(node)
        return "" if children.empty?

        carousel_id = SecureRandom.hex(8)
        context[:component_head_styles] << component_head_style(carousel_id, children.length, a)

        outer_td_attrs = {
          "align" => a["align"],
          "class" => a["css-class"],
          "style" => style_join(
            "background" => a["container-background-color"],
            "font-size" => "0px",
            "padding" => a["padding"],
            "padding-top" => a["padding-top"],
            "padding-right" => a["padding-right"],
            "padding-bottom" => a["padding-bottom"],
            "padding-left" => a["padding-left"],
            "word-break" => "break-word"
          )
        }

        inner_container_width = content_width(context[:container_width], a)

        content = <<~HTML
          #{mso_conditional_tag(interactive_markup(node, children, context, a, carousel_id, inner_container_width), true)}
          #{render_fallback(node, children.first, context, a, inner_container_width)}
        HTML

        %(<tr><td#{html_attrs(outer_td_attrs)}>#{content}</td></tr>)
      end

      private

      def interactive_markup(node, children, context, attrs, carousel_id, inner_container_width)
        carousel_classes = ["mj-carousel", attrs["css-class"]].compact.reject(&:empty?).join(" ")

        <<~HTML
          <div#{html_attrs("class" => carousel_classes)}>
            #{generate_radios(children, carousel_id)}
            <div#{html_attrs(
              "class" => "mj-carousel-content mj-carousel-#{carousel_id}-content",
              "style" => style_join(
                "display" => "table",
                "width" => "100%",
                "table-layout" => "fixed",
                "text-align" => "center",
                "font-size" => "0px"
              )
            )}>
              #{generate_thumbnails(node, children, context, attrs, carousel_id, inner_container_width)}
              #{generate_carousel(node, children, context, attrs, carousel_id, inner_container_width)}
            </div>
          </div>
        HTML
      end

      def generate_radios(children, carousel_id)
        image_component = carousel_image_component
        children.each_with_index.map do |child, index|
          image_component.render_radio(index: index, carousel_id: carousel_id)
        end.join
      end

      def generate_thumbnails(node, children, context, attrs, carousel_id, inner_container_width)
        thumbnails = attrs["thumbnails"]
        return "" unless %w[visible supported].include?(thumbnails)

        image_component = carousel_image_component
        tb_width = thumbnail_width(attrs, children.length, inner_container_width)

        with_inherited_mj_class(context, node) do
          children.each_with_index.map do |child, index|
            child_attrs = child_pass_through_attributes(child, context, attrs, tb_width)
            image_component.render_thumbnail(
              child,
              attrs: child_attrs,
              index: index,
              carousel_id: carousel_id,
              thumbnails: thumbnails,
              tb_width: tb_width
            )
          end.join
        end
      end

      def generate_carousel(node, children, context, attrs, carousel_id, inner_container_width)
        <<~HTML
          <table#{html_attrs(
            "style" => style_join(
              "caption-side" => "top",
              "display" => "table-caption",
              "table-layout" => "fixed",
              "width" => "100%"
            ),
            "border" => "0",
            "cellpadding" => "0",
            "cellspacing" => "0",
            "width" => "100%",
            "role" => "presentation",
            "class" => "mj-carousel-main"
          )}>
            <tbody>
              <tr>
                #{generate_controls("previous", attrs["left-icon"], carousel_id, children.length, attrs["icon-width"])}
                #{generate_images(node, children, context, attrs, inner_container_width)}
                #{generate_controls("next", attrs["right-icon"], carousel_id, children.length, attrs["icon-width"])}
              </tr>
            </tbody>
          </table>
        HTML
      end

      def generate_controls(direction, icon, carousel_id, child_count, icon_width)
        parsed_icon_width = parse_pixel_value(icon_width).to_i

        labels = (1..child_count).map do |index|
          <<~HTML
            <label#{html_attrs(
              "for" => "mj-carousel-#{carousel_id}-radio-#{index}",
              "class" => "mj-carousel-#{direction} mj-carousel-#{direction}-#{index}"
            )}>
              <img#{html_attrs(
                "src" => icon,
                "alt" => direction,
                "style" => style_join(
                  "display" => "block",
                  "width" => icon_width,
                  "height" => "auto"
                ),
                "width" => parsed_icon_width.to_s
              )} />
            </label>
          HTML
        end.join

        <<~HTML
          <td#{html_attrs(
            "class" => "mj-carousel-#{carousel_id}-icons-cell",
            "style" => style_join(
              "font-size" => "0px",
              "display" => "none",
              "mso-hide" => "all",
              "padding" => "0px"
            )
          )}>
            <div#{html_attrs(
              "class" => "mj-carousel-#{direction}-icons",
              "style" => style_join(
                "display" => "none",
                "mso-hide" => "all"
              )
            )}>
              #{labels}
            </div>
          </td>
        HTML
      end

      def generate_images(node, children, context, attrs, inner_container_width)
        image_component = carousel_image_component
        images = with_inherited_mj_class(context, node) do
          children.each_with_index.map do |child, index|
            child_attrs = child_pass_through_attributes(child, context, attrs, nil)
            image_component.render_item(
              child,
              attrs: child_attrs,
              index: index,
              container_width: inner_container_width,
              visible: index.zero?
            )
          end.join
        end

        <<~HTML
          <td#{html_attrs("style" => "padding:0px;")}>
            <div#{html_attrs("class" => "mj-carousel-images")}>
              #{images}
            </div>
          </td>
        HTML
      end

      def render_fallback(node, first_child, context, attrs, inner_container_width)
        return "" unless first_child

        child_attrs = with_inherited_mj_class(context, node) do
          child_pass_through_attributes(first_child, context, attrs, nil)
        end
        fallback = carousel_image_component.render_item(
          first_child,
          attrs: child_attrs,
          index: 0,
          container_width: inner_container_width,
          visible: true
        )
        mso_conditional_tag(fallback)
      end

      def child_pass_through_attributes(child, context, parent_attrs, tb_width)
        child_attrs = resolved_attributes(child, context)
        pass_through = {
          "border-radius" => parent_attrs["border-radius"],
          "tb-border" => parent_attrs["tb-border"],
          "tb-border-radius" => parent_attrs["tb-border-radius"]
        }
        pass_through["tb-width"] = tb_width if tb_width
        pass_through.merge(child_attrs)
      end

      def carousel_images(node)
        node.element_children.select { |child| child.tag_name == "mj-carousel-image" }
      end

      def carousel_image_component
        renderer.send(:component_for, "mj-carousel-image")
      end

      def thumbnail_width(attrs, child_count, inner_container_width)
        return attrs["tb-width"] if attrs["tb-width"] && !attrs["tb-width"].empty?
        return "0px" if child_count.zero?

        "#{[inner_container_width.to_f / child_count, 110].min}px"
      end

      def content_width(container_width, attrs)
        total = parse_pixel_value(container_width || "600px")
        total -= padding_side(attrs, "left")
        total -= padding_side(attrs, "right")
        [total, 0].max
      end

      def padding_side(attrs, side)
        specific = attrs["padding-#{side}"]
        return parse_pixel_value(specific) unless blank?(specific)

        shorthand_padding_value(attrs["padding"], side)
      end

      def shorthand_padding_value(value, side)
        return 0 if blank?(value)

        parts = value.to_s.strip.split(/\s+/)
        case parts.length
        when 1
          parse_pixel_value(parts[0])
        when 2
          %w[left right].include?(side) ? parse_pixel_value(parts[1]) : parse_pixel_value(parts[0])
        when 3
          %w[left right].include?(side) ? parse_pixel_value(parts[1]) : parse_pixel_value(side == "top" ? parts[0] : parts[2])
        when 4
          parse_pixel_value(parts[side == "left" ? 3 : 1])
        else
          0
        end
      end

      def component_head_style(carousel_id, length, attrs)
        return "" if length.zero?

        hide_non_selected = []
        show_selected = []
        next_icons = []
        previous_icons = []
        selected_thumbnail = []
        show_thumbnails = []
        hide_on_hover = []
        show_on_hover = []

        # Pre-compute adjacent sibling strings to avoid repeated "+" * count" allocations
        sibling_cache = Array.new(length) { |i| adjacent_siblings(i) }

        length.times do |index|
          siblings_index = sibling_cache[index]
          siblings_reverse = sibling_cache[length - index - 1]
          idx1 = index + 1
          next_target = ((index + 1) % length) + 1
          prev_target = ((index - 1) % length) + 1

          hide_non_selected << ".mj-carousel-#{carousel_id}-radio:checked #{siblings_index}+ .mj-carousel-content .mj-carousel-image"
          show_selected << ".mj-carousel-#{carousel_id}-radio-#{idx1}:checked #{siblings_reverse}+ .mj-carousel-content .mj-carousel-image-#{idx1}"
          next_icons << ".mj-carousel-#{carousel_id}-radio-#{idx1}:checked #{siblings_reverse}+ .mj-carousel-content .mj-carousel-next-#{next_target}"
          previous_icons << ".mj-carousel-#{carousel_id}-radio-#{idx1}:checked #{siblings_reverse}+ .mj-carousel-content .mj-carousel-previous-#{prev_target}"
          selected_thumbnail << ".mj-carousel-#{carousel_id}-radio-#{idx1}:checked #{siblings_reverse}+ .mj-carousel-content .mj-carousel-#{carousel_id}-thumbnail-#{idx1}"
          show_thumbnails << ".mj-carousel-#{carousel_id}-radio-#{idx1}:checked #{siblings_reverse}+ .mj-carousel-content .mj-carousel-#{carousel_id}-thumbnail"
          hide_on_hover << ".mj-carousel-#{carousel_id}-thumbnail:hover #{siblings_reverse}+ .mj-carousel-main .mj-carousel-image"
          show_on_hover << ".mj-carousel-#{carousel_id}-thumbnail-#{idx1}:hover #{siblings_reverse}+ .mj-carousel-main .mj-carousel-image-#{idx1}"
        end

        hide_non_selected = hide_non_selected.join(",\n")
        show_selected = show_selected.join(",\n")
        next_icons = next_icons.join(",\n")
        previous_icons = previous_icons.join(",\n")
        selected_thumbnail = selected_thumbnail.join(",\n")
        show_thumbnails = show_thumbnails.join(",\n")
        hide_on_hover = hide_on_hover.join(",\n")
        show_on_hover = show_on_hover.join(",\n")

        <<~CSS
          .mj-carousel {
            -webkit-user-select: none;
            -moz-user-select: none;
            user-select: none;
          }

          .mj-carousel-#{carousel_id}-icons-cell {
            display: table-cell !important;
            width: #{attrs["icon-width"]} !important;
          }

          .mj-carousel-radio,
          .mj-carousel-next,
          .mj-carousel-previous {
            display: none !important;
          }

          .mj-carousel-thumbnail,
          .mj-carousel-next,
          .mj-carousel-previous {
            touch-action: manipulation;
          }

          #{hide_non_selected} {
            display: none !important;
          }

          #{show_selected} {
            display: block !important;
          }

          .mj-carousel-previous-icons,
          .mj-carousel-next-icons,
          #{next_icons},
          #{previous_icons} {
            display: block !important;
          }

          #{selected_thumbnail} {
            border-color: #{attrs["tb-selected-border-color"]} !important;
          }

          #{show_thumbnails} {
            display: inline-block !important;
          }

          .mj-carousel-image img + div,
          .mj-carousel-thumbnail img + div {
            display: none !important;
          }

          #{hide_on_hover} {
            display: none !important;
          }

          .mj-carousel-thumbnail:hover {
            border-color: #{attrs["tb-hover-border-color"]} !important;
          }

          #{show_on_hover} {
            display: block !important;
          }

          .mj-carousel noinput { display:block !important; }
          .mj-carousel noinput .mj-carousel-image-1 { display: block !important; }
          .mj-carousel noinput .mj-carousel-arrows,
          .mj-carousel noinput .mj-carousel-thumbnails { display: none !important; }

          [owa] .mj-carousel-thumbnail { display: none !important; }

          @media screen yahoo {
            .mj-carousel-#{carousel_id}-icons-cell,
            .mj-carousel-previous-icons,
            .mj-carousel-next-icons {
              display: none !important;
            }

            .mj-carousel-#{carousel_id}-radio-1:checked #{adjacent_siblings(length - 1)}+ .mj-carousel-content .mj-carousel-#{carousel_id}-thumbnail-1 {
              border-color: transparent;
            }
          }
        CSS
      end

      def adjacent_siblings(count)
        "+ * " * count
      end

      def mso_conditional_tag(content, negation = false)
        if negation
          "<!--[if !mso]><!-->#{content}<!--<![endif]-->"
        else
          "<!--[if mso]>#{content}<![endif]-->"
        end
      end

      def parse_pixel_value(value)
        matched = value.to_s.match(/(-?\d+(?:\.\d+)?)/)
        matched ? matched[1].to_f : 0.0
      end

      def blank?(value)
        value.nil? || value.to_s.strip.empty?
      end
    end
  end
end
