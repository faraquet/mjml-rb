require_relative "base"

module MjmlRb
  module Components
    class Group < Base
      TAGS = ["mj-group"].freeze

      ALLOWED_ATTRIBUTES = {
        "background-color" => "color",
        "direction" => "enum(ltr,rtl)",
        "vertical-align" => "enum(top,bottom,middle)",
        "width" => "unit(px,%)"
      }.freeze

      DEFAULT_ATTRIBUTES = {
        "direction" => "ltr"
      }.freeze

      def tags
        TAGS
      end

      def render(tag_name:, node:, context:, attrs:, parent:)
        width_pct = context.delete(:_column_width_pct) || 100.0
        a = DEFAULT_ATTRIBUTES.merge(attrs)
        css_class = a["css-class"]

        pct_str = width_pct.to_f.to_s.sub(/\.?0+$/, "")
        col_class_name = "mj-column-per-#{pct_str.gsub('.', '-')}"
        context[:column_widths][col_class_name] = "#{pct_str}%" if context[:column_widths]

        group_class = "#{col_class_name} mj-outlook-group-fix"
        group_class = "#{group_class} #{css_class}" if css_class && !css_class.empty?

        group_width = group_container_width(context, a, width_pct)
        div_style = style_join(
          "font-size" => "0",
          "line-height" => "0",
          "text-align" => "left",
          "display" => "inline-block",
          "width" => "100%",
          "direction" => a["direction"],
          "vertical-align" => a["vertical-align"],
          "background-color" => a["background-color"]
        )

        inner = with_group_container_width(context, group_width) do
          render_group_children(node, context, a, group_width)
        end

        %(<div class="#{escape_attr(group_class)}" style="#{div_style}">#{inner}</div>)
      end

      private

      def render_group_children(node, context, attrs, group_width)
        columns = node.element_children.select { |child| child.tag_name == "mj-column" }
        widths = renderer.send(:compute_column_widths, columns, context)
        group_width_px = parse_pixel_value(group_width)
        group_bg = attrs["background-color"]
        table_attrs = {
          "bgcolor" => (group_bg == "none" ? nil : group_bg),
          "border" => "0",
          "cellpadding" => "0",
          "cellspacing" => "0",
          "role" => "presentation"
        }

        open_table = %(<!--[if mso | IE]><table#{html_attrs(table_attrs)}><tr><![endif]-->)
        close_table = %(<!--[if mso | IE]></tr></table><![endif]-->)
        column_index = 0

        body = with_inherited_mj_class(context, node) do
          node.children.map do |child|
            case child.tag_name
            when "mj-column"
              width_pct = widths[column_index] || 100.0
              column_index += 1
              context[:_column_width_pct] = width_pct
              context[:_column_mobile_width] = true
              td_style = style_join(
                "vertical-align" => resolved_attributes(child, context)["vertical-align"] || "top",
                "width" => "#{(group_width_px * width_pct / 100.0).round}px"
              )
              td_open = %(<!--[if mso | IE]><td#{html_attrs("style" => td_style)}><![endif]-->)
              td_close = %(<!--[if mso | IE]></td><![endif]-->)
              "#{td_open}#{render_node(child, context, parent: "mj-group")}#{td_close}"
            when "mj-raw"
              render_node(child, context, parent: "mj-group")
            else
              render_node(child, context, parent: "mj-group")
            end
          end.join("\n")
        end

        "#{open_table}#{body}#{close_table}"
      end

      def with_group_container_width(context, width)
        previous = context[:container_width]
        context[:container_width] = width
        yield
      ensure
        context[:container_width] = previous
      end

      def group_container_width(context, attrs, width_pct)
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

        "#{[raw_width, 0].max}px"
      end

      def present_attr?(value)
        value && !value.empty?
      end

      def parse_pixel_value(value)
        return 0.0 unless present_attr?(value)

        matched = value.to_s.match(/(-?\d+(?:\.\d+)?)/)
        matched ? matched[1].to_f : 0.0
      end
    end
  end
end
