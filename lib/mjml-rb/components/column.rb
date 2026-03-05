require_relative "base"

module MjmlRb
  module Components
    class Column < Base
      TAGS = %w[mj-column].freeze

      def tags
        TAGS
      end

      GUTTER_ATTRIBUTES = %w[padding padding-top padding-right padding-bottom padding-left].freeze

      def render(tag_name:, node:, context:, attrs:, parent:)
        width_pct = context.delete(:_column_width_pct) || 100.0
        css_class = attrs["css-class"]

        pct_str = width_pct.to_f.to_s.sub(/\.?0+$/, "")
        col_class_suffix = pct_str.gsub(".", "-")
        context[:column_widths][col_class_suffix] = pct_str if context[:column_widths]

        col_class = "mj-column-per-#{col_class_suffix} mj-outlook-group-fix"
        col_class = "#{col_class} #{css_class}" if css_class && !css_class.empty?

        vertical_align = attrs["vertical-align"] || "top"
        column_direction = attrs["direction"] || "ltr"
        col_style = style_join(
          "font-size" => "0px",
          "text-align" => "left",
          "direction" => column_direction,
          "display" => "inline-block",
          "vertical-align" => vertical_align,
          "width" => "100%"
        )

        content =
          if gutter?(attrs)
            render_gutter(node, context, attrs, vertical_align)
          else
            render_column(node, context, attrs, vertical_align, inside_gutter: false)
          end

        %(<div class="#{escape_attr(col_class)}" style="#{col_style}">#{content}</div>)
      end

      private

      def gutter?(attrs)
        GUTTER_ATTRIBUTES.any? { |name| attrs[name] && !attrs[name].empty? }
      end

      def render_gutter(node, context, attrs, vertical_align)
        table_attrs = {
          "border" => "0",
          "cellpadding" => "0",
          "cellspacing" => "0",
          "role" => "presentation",
          "width" => "100%",
          "style" => (has_border_radius?(attrs) ? "border-collapse:separate" : nil)
        }

        td_attrs = {
          "style" => style_join(
            table_style(attrs, vertical_align),
            gutter_style(attrs, vertical_align)
          )
        }

        %(<table#{html_attrs(table_attrs)}><tbody><tr><td#{html_attrs(td_attrs)}>#{render_column(node, context, attrs, vertical_align, inside_gutter: true)}</td></tr></tbody></table>)
      end

      def render_column(node, context, attrs, vertical_align, inside_gutter:)
        table_attrs = {
          "border" => "0",
          "cellpadding" => "0",
          "cellspacing" => "0",
          "role" => "presentation",
          "width" => "100%"
        }

        table_style_hash =
          if inside_gutter
            inner_table_style(attrs)
          else
            table_style(attrs, vertical_align)
          end
        table_attrs["style"] = style_join(table_style_hash) if table_style_hash.any?

        children = render_children(node, context, parent: "mj-column")
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

      def style_join(*hashes)
        super(hashes.reduce({}, :merge))
      end
    end
  end
end
