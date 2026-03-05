require_relative "base"

module MjmlRb
  module Components
    class Column < Base
      TAGS = %w[mj-column].freeze

      ALLOWED_ATTRIBUTES = {
        "background-color" => "color",
        "border" => "string",
        "border-bottom" => "string",
        "border-left" => "string",
        "border-radius" => "unit(px,%){1,4}",
        "border-right" => "string",
        "border-top" => "string",
        "direction" => "enum(ltr,rtl)",
        "inner-background-color" => "color",
        "inner-border" => "string",
        "inner-border-bottom" => "string",
        "inner-border-left" => "string",
        "inner-border-radius" => "unit(px,%){1,4}",
        "inner-border-right" => "string",
        "inner-border-top" => "string",
        "padding" => "unit(px,%){1,4}",
        "padding-bottom" => "unit(px,%)",
        "padding-left" => "unit(px,%)",
        "padding-right" => "unit(px,%)",
        "padding-top" => "unit(px,%)",
        "vertical-align" => "enum(top,bottom,middle)",
        "width" => "unit(px,%)"
      }.freeze

      DEFAULT_ATTRIBUTES = {
        "direction" => "ltr",
        "vertical-align" => "top"
      }.freeze

      GUTTER_ATTRIBUTES = %w[padding padding-top padding-right padding-bottom padding-left].freeze

      def render(tag_name:, node:, context:, attrs:, parent:)
        width_pct = context.delete(:_column_width_pct) || 100.0
        css_class = attrs["css-class"]
        a = self.class.default_attributes.merge(attrs)

        pct_str          = width_pct.to_f.to_s.sub(/\.?0+$/, "")
        col_class_suffix = pct_str.gsub(".", "-")
        context[:column_widths][col_class_suffix] = pct_str if context[:column_widths]

        col_class = "mj-column-per-#{col_class_suffix} mj-outlook-group-fix"
        col_class = "#{col_class} #{css_class}" if css_class && !css_class.empty?

        vertical_align = a["vertical-align"]
        col_style = style_join(
          "font-size" => "0px",
          "text-align" => "left",
          "direction" => a["direction"],
          "display" => "inline-block",
          "vertical-align" => vertical_align,
          "width" => "100%"
        )

        column_markup =
          if gutter?(a)
            render_gutter(node, context, a, vertical_align, width_pct)
          else
            render_column(node, context, a, vertical_align, width_pct, inside_gutter: false)
          end

        %(<div class="#{escape_attr(col_class)}" style="#{col_style}">#{column_markup}</div>)
      end

      private

      def gutter?(attrs)
        GUTTER_ATTRIBUTES.any? { |name| attrs[name] && !attrs[name].empty? }
      end

      def render_gutter(node, context, attrs, vertical_align, width_pct)
        table_attrs = {
          "border" => "0",
          "cellpadding" => "0",
          "cellspacing" => "0",
          "role" => "presentation",
          "width" => "100%",
          "style" => (has_border_radius?(attrs) ? "border-collapse:separate" : nil)
        }
        td_attrs = {
          "style" => style_join(table_style(attrs, vertical_align).merge(gutter_style(attrs, vertical_align)))
        }

        %(<table#{html_attrs(table_attrs)}><tbody><tr><td#{html_attrs(td_attrs)}>#{render_column(node, context, attrs, vertical_align, width_pct, inside_gutter: true)}</td></tr></tbody></table>)
      end

      def render_column(node, context, attrs, vertical_align, width_pct, inside_gutter:)
        table_attrs = {
          "border" => "0",
          "cellpadding" => "0",
          "cellspacing" => "0",
          "role" => "presentation",
          "width" => "100%"
        }

        styles = inside_gutter ? inner_table_style(attrs) : table_style(attrs, vertical_align)
        table_attrs["style"] = style_join(styles) if styles.any?

        children = with_child_container_width(context, attrs, width_pct) do
          render_children(node, context, parent: "mj-column")
        end
        %(<table#{html_attrs(table_attrs)}><tbody>#{children}</tbody></table>)
      end

      def table_style(attrs, vertical_align)
        style = {
          "background-color" => attrs["background-color"],
          "border" => attrs["border"],
          "border-bottom" => attrs["border-bottom"],
          "border-left" => attrs["border-left"],
          "border-radius" => attrs["border-radius"],
          "border-right" => attrs["border-right"],
          "border-top" => attrs["border-top"],
          "vertical-align" => vertical_align
        }
        style["border-collapse"] = "separate" if has_border_radius?(attrs)
        style
      end

      def inner_table_style(attrs)
        style = {
          "background-color" => attrs["inner-background-color"],
          "border" => attrs["inner-border"],
          "border-bottom" => attrs["inner-border-bottom"],
          "border-left" => attrs["inner-border-left"],
          "border-radius" => attrs["inner-border-radius"],
          "border-right" => attrs["inner-border-right"],
          "border-top" => attrs["inner-border-top"]
        }
        style["border-collapse"] = "separate" if has_inner_border_radius?(attrs)
        style
      end

      def gutter_style(attrs, vertical_align)
        {
          "padding" => attrs["padding"],
          "padding-top" => attrs["padding-top"],
          "padding-right" => attrs["padding-right"],
          "padding-bottom" => attrs["padding-bottom"],
          "padding-left" => attrs["padding-left"],
          "vertical-align" => vertical_align
        }
      end

      def has_border_radius?(attrs)
        present_attr?(attrs["border-radius"])
      end

      def has_inner_border_radius?(attrs)
        present_attr?(attrs["inner-border-radius"])
      end

      def present_attr?(value)
        value && !value.empty?
      end

      def with_child_container_width(context, attrs, width_pct)
        previous_container_width = context[:container_width]
        context[:container_width] = child_container_width(context, attrs, width_pct)
        yield
      ensure
        context[:container_width] = previous_container_width
      end

      def child_container_width(context, attrs, width_pct)
        parent_width = parse_pixel_value(context[:container_width] || "600px")
        width = attrs["width"]
        raw_width =
          if present_attr?(width) && width.end_with?("%")
            parent_width * parse_pixel_value(width) / 100.0
          elsif present_attr?(width) && width.end_with?("px")
            parse_pixel_value(width)
          else
            parent_width * width_pct / 100.0
          end

        all_paddings = horizontal_padding_width(attrs) +
                       horizontal_border_width(attrs, "border") +
                       horizontal_border_width(attrs, "inner-border")

        "#{[raw_width - all_paddings, 0].max}px"
      end

      def horizontal_padding_width(attrs)
        padding_value(attrs, "left") + padding_value(attrs, "right")
      end

      def padding_value(attrs, side)
        specific_padding = attrs["padding-#{side}"]
        return parse_pixel_value(specific_padding) if present_attr?(specific_padding)

        shorthand_padding_value(attrs["padding"], side)
      end

      def shorthand_padding_value(value, side)
        return 0.0 unless present_attr?(value)

        parts = value.split(/\s+/)
        case parts.length
        when 1
          parse_pixel_value(parts[0])
        when 2
          side == "left" || side == "right" ? parse_pixel_value(parts[1]) : parse_pixel_value(parts[0])
        when 3
          side == "left" || side == "right" ? parse_pixel_value(parts[1]) : parse_pixel_value(side == "top" ? parts[0] : parts[2])
        when 4
          parse_pixel_value(parts[side == "left" ? 3 : 1])
        else
          0.0
        end
      end

      def horizontal_border_width(attrs, attribute_prefix)
        border_width(attrs["#{attribute_prefix}-left"] || attrs[attribute_prefix]) +
          border_width(attrs["#{attribute_prefix}-right"] || attrs[attribute_prefix])
      end

      def border_width(value)
        return 0.0 unless present_attr?(value)
        return 0.0 if value.strip == "none"

        matched = value.match(/(-?\d+(?:\.\d+)?)px/)
        matched ? matched[1].to_f : 0.0
      end

      def parse_pixel_value(value)
        return 0.0 unless present_attr?(value)

        matched = value.to_s.match(/(-?\d+(?:\.\d+)?)/)
        matched ? matched[1].to_f : 0.0
      end
    end
  end
end
