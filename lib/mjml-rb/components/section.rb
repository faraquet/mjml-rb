require_relative "base"

module MjmlRb
  module Components
    class Section < Base
      TAGS = %w[mj-section mj-wrapper].freeze

      SECTION_DEFAULTS = {
        "direction"  => "ltr",
        "padding"    => "20px 0",
        "text-align" => "center"
      }.freeze

      def tags
        TAGS
      end

      def render(tag_name:, node:, context:, attrs:, parent:)
        case tag_name
        when "mj-wrapper"
          render_wrapper(node, context, attrs)
        else
          render_section(node, context, attrs)
        end
      end

      private

      # ── Shared helpers ──────────────────────────────────────────────────────

      def parse_px(value)
        value.to_s.to_i
      end

      def parse_border_width(border_str)
        return 0 if border_str.nil? || border_str.to_s.strip.empty? || border_str.to_s.strip == "none"

        border_str =~ /(\d+(?:\.\d+)?)\s*px/ ? $1.to_i : 0
      end

      def parse_padding_value(str)
        return 0 if str.nil? || str.to_s.strip.empty?

        str =~ /(\d+(?:\.\d+)?)\s*px/ ? $1.to_i : 0
      end

      def parse_padding_side(attrs, side)
        specific = attrs["padding-#{side}"]
        return parse_padding_value(specific) if specific && !specific.to_s.empty?

        shorthand = attrs["padding"]
        return 0 unless shorthand

        parts = shorthand.to_s.strip.split(/\s+/)
        case parts.size
        when 1 then parse_padding_value(parts[0])
        when 2
          side == "left" || side == "right" ? parse_padding_value(parts[1]) : parse_padding_value(parts[0])
        when 3
          case side
          when "top"         then parse_padding_value(parts[0])
          when "right", "left" then parse_padding_value(parts[1])
          when "bottom"      then parse_padding_value(parts[2])
          else 0
          end
        when 4
          idx = {"top" => 0, "right" => 1, "bottom" => 2, "left" => 3}[side]
          parse_padding_value(parts[idx] || "0")
        else
          0
        end
      end

      # Merge adjacent Outlook conditional comments.  Applied locally within
      # each section/wrapper to avoid incorrectly merging across sibling sections.
      def merge_outlook_conditionals(html)
        html.gsub(/<!\[endif\]-->\s*<!--\[if mso \| IE\]>/m, "")
      end

      # Build an attribute string for Outlook conditional comment tags.
      # Always renders every pair (including class="") and appends a trailing
      # space before the > to match MJML's htmlAttributes output.
      def outlook_attrs(pairs)
        parts = pairs.map { |(key, value)| %(#{key}="#{escape_attr(value.to_s)}") }
        " #{parts.join(' ')} "
      end

      # ── mj-section ─────────────────────────────────────────────────────────

      def render_section(node, context, attrs)
        a            = SECTION_DEFAULTS.merge(attrs)
        container_px = parse_px(context[:container_width] || "600px")
        css_class    = a["css-class"]
        bg_color     = a["background-color"]

        # Box width: container minus horizontal padding and borders
        border_left  = parse_border_width(a["border-left"] || a["border"])
        border_right = parse_border_width(a["border-right"] || a["border"])
        pad_left     = parse_padding_side(a, "left")
        pad_right    = parse_padding_side(a, "right")
        box_width    = container_px - pad_left - pad_right - border_left - border_right

        # renderBefore — Outlook outer wrapper table
        outlook_class = css_class ? "#{css_class}-outlook" : ""
        before_pairs = [
          ["align",       "center"],
          ["border",      "0"],
          ["cellpadding", "0"],
          ["cellspacing", "0"],
          ["class",       outlook_class],
          ["role",        "presentation"],
          ["style",       "width:#{container_px}px;"],
          ["width",       container_px.to_s]
        ]
        before_pairs << ["bgcolor", bg_color] if bg_color

        render_before = %(<!--[if mso | IE]><table#{outlook_attrs(before_pairs)}><tr><td style="line-height:0px;font-size:0px;mso-line-height-rule:exactly;"><![endif]-->)

        # Section div, table, td
        div_style = style_join(
          "background"       => bg_color,
          "background-color" => bg_color,
          "margin"           => "0px auto",
          "max-width"        => "#{container_px}px"
        )

        border_val = a["border"]
        border_val = nil if border_val.nil? || border_val.to_s.strip.empty? || border_val.to_s.strip == "none"

        td_style = style_join(
          "border"         => border_val,
          "border-top"     => a["border-top"],
          "border-right"   => a["border-right"],
          "border-bottom"  => a["border-bottom"],
          "border-left"    => a["border-left"],
          "direction"      => a["direction"],
          "font-size"      => "0px",
          "padding"        => a["padding"],
          "padding-top"    => a["padding-top"],
          "padding-right"  => a["padding-right"],
          "padding-bottom" => a["padding-bottom"],
          "padding-left"   => a["padding-left"],
          "text-align"     => a["text-align"]
        )

        table_style = style_join(
          "background"       => bg_color,
          "background-color" => bg_color,
          "width"            => "100%"
        )

        div_attrs = {"class" => css_class, "style" => div_style}
        inner = merge_outlook_conditionals(render_section_columns(node, context, box_width))

        section_html =
          %(<div#{html_attrs(div_attrs)}>) +
          %(<table align="center" border="0" cellpadding="0" cellspacing="0" role="presentation" style="#{table_style}">) +
          %(<tbody><tr><td style="#{td_style}">#{inner}</td></tr></tbody></table></div>)

        render_after = %(<!--[if mso | IE]></td></tr></table><![endif]-->)

        "#{render_before}\n#{section_html}\n#{render_after}"
      end

      # Generate Outlook IE conditional wrappers around each column/group.
      def render_section_columns(node, context, box_width)
        columns = node.element_children.select { |e| %w[mj-column mj-group].include?(e.tag_name) }
        return render_children(node, context, parent: "mj-section") if columns.empty?

        widths = renderer.send(:compute_column_widths, columns, context)

        open_table  = %(<!--[if mso | IE]><table role="presentation" border="0" cellpadding="0" cellspacing="0"><![endif]-->)
        open_tr     = %(<!--[if mso | IE]><tr><![endif]-->)
        close_tr    = %(<!--[if mso | IE]></tr><![endif]-->)
        close_table = %(<!--[if mso | IE]></table><![endif]-->)

        col_parts = columns.each_with_index.map do |col, i|
          col_attrs = resolved_attributes(col, context)
          v_align   = col_attrs["vertical-align"] || "top"
          col_px    = (box_width.to_f * widths[i] / 100.0).round

          td_open  = %(<!--[if mso | IE]><td class="" style="vertical-align:#{v_align};width:#{col_px}px;" ><![endif]-->)
          td_close = %(<!--[if mso | IE]></td><![endif]-->)

          col_html = if col.tag_name == "mj-group"
                       renderer.send(:render_group, col, context, widths[i])
                     else
                       context[:_column_width_pct] = widths[i]
                       render_node(col, context, parent: "mj-section")
                     end

          "#{td_open}\n#{col_html}\n#{td_close}"
        end

        ([open_table, open_tr] + col_parts + [close_tr, close_table]).join("\n")
      end

      # ── mj-wrapper ─────────────────────────────────────────────────────────

      def render_wrapper(node, context, attrs)
        a            = SECTION_DEFAULTS.merge(attrs)
        container_px = parse_px(context[:container_width] || "600px")
        css_class    = a["css-class"]
        bg_color     = a["background-color"]

        # renderBefore — same structure as section
        outlook_class = css_class ? "#{css_class}-outlook" : ""
        before_pairs = [
          ["align",       "center"],
          ["border",      "0"],
          ["cellpadding", "0"],
          ["cellspacing", "0"],
          ["class",       outlook_class],
          ["role",        "presentation"],
          ["style",       "width:#{container_px}px;"],
          ["width",       container_px.to_s]
        ]
        before_pairs << ["bgcolor", bg_color] if bg_color

        render_before = %(<!--[if mso | IE]><table#{outlook_attrs(before_pairs)}><tr><td style="line-height:0px;font-size:0px;mso-line-height-rule:exactly;"><![endif]-->)

        div_style = style_join(
          "background"       => bg_color,
          "background-color" => bg_color,
          "margin"           => "0px auto",
          "max-width"        => "#{container_px}px"
        )

        table_style = style_join(
          "background"       => bg_color,
          "background-color" => bg_color,
          "width"            => "100%"
        )

        td_style = style_join(
          "direction"      => a["direction"],
          "font-size"      => "0px",
          "padding"        => a["padding"],
          "padding-top"    => a["padding-top"],
          "padding-right"  => a["padding-right"],
          "padding-bottom" => a["padding-bottom"],
          "padding-left"   => a["padding-left"],
          "text-align"     => a["text-align"]
        )

        div_attrs = {"class" => css_class, "style" => div_style}
        inner = merge_outlook_conditionals(render_wrapped_children_wrapper(node, context, container_px))

        wrapper_html =
          %(<div#{html_attrs(div_attrs)}>) +
          %(<table align="center" border="0" cellpadding="0" cellspacing="0" role="presentation" style="#{table_style}">) +
          %(<tbody><tr><td style="#{td_style}">#{inner}</td></tr></tbody></table></div>)

        render_after = %(<!--[if mso | IE]></td></tr></table><![endif]-->)

        "#{render_before}\n#{wrapper_html}\n#{render_after}"
      end

      # Wrap each child mj-section/mj-wrapper in an Outlook conditional <td>.
      def render_wrapped_children_wrapper(node, context, container_px)
        children = node.element_children.select { |e| %w[mj-section mj-wrapper].include?(e.tag_name) }
        return render_children(node, context, parent: "mj-wrapper") if children.empty?

        open_table  = %(<!--[if mso | IE]><table role="presentation" border="0" cellpadding="0" cellspacing="0"><![endif]-->)
        open_tr     = %(<!--[if mso | IE]><tr><![endif]-->)
        close_tr    = %(<!--[if mso | IE]></tr><![endif]-->)
        close_table = %(<!--[if mso | IE]></table><![endif]-->)

        section_parts = children.map do |child|
          td_open  = %(<!--[if mso | IE]><td class="" width="#{container_px}px" ><![endif]-->)
          td_close = %(<!--[if mso | IE]></td><![endif]-->)
          child_html = render_node(child, context, parent: "mj-wrapper")
          "#{td_open}\n#{child_html}\n#{td_close}"
        end

        ([open_table, open_tr] + section_parts + [close_tr, close_table]).join("\n")
      end
    end
  end
end
