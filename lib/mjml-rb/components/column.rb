require_relative "base"

module MjmlRb
  module Components
    class Column < Base
      TAGS = %w[mj-column].freeze

      def tags
        TAGS
      end

      def render(tag_name:, node:, context:, attrs:, parent:)
        width_pct = context.delete(:_column_width_pct) || 100.0
        css_class = attrs["css-class"]

        pct_str          = width_pct.to_f.to_s.sub(/\.?0+$/, "")
        col_class_suffix = pct_str.gsub(".", "-")
        context[:column_widths][col_class_suffix] = pct_str if context[:column_widths]

        col_class = "mj-column-per-#{col_class_suffix} mj-outlook-group-fix"
        col_class = "#{col_class} #{css_class}" if css_class && !css_class.empty?

        v_align = attrs["vertical-align"] || "top"
        col_style = style_join(
          "font-size"      => "0px",
          "text-align"     => "left",
          "direction"      => "ltr",
          "display"        => "inline-block",
          "vertical-align" => v_align,
          "width"          => "100%"
        )
        children = render_children(node, context, parent: "mj-column")

        %(<div class="#{escape_attr(col_class)}" style="#{col_style}"><table border="0" cellpadding="0" cellspacing="0" role="presentation" style="vertical-align:#{escape_attr(v_align)};" width="100%"><tbody>#{children}</tbody></table></div>)
      end
    end
  end
end
