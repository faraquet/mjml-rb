require_relative "base"

module MjmlRb
  module Components
    class Section < Base
      TAGS = %w[mj-section mj-wrapper].freeze

      SECTION_ALLOWED_ATTRIBUTES = {
        "background-color" => "color",
        "background-url" => "string",
        "background-repeat" => "enum(repeat,no-repeat)",
        "background-size" => "string",
        "background-position" => "string",
        "background-position-x" => "string",
        "background-position-y" => "string",
        "border" => "string",
        "border-bottom" => "string",
        "border-left" => "string",
        "border-radius" => "unit(px,%){1,4}",
        "border-right" => "string",
        "border-top" => "string",
        "direction" => "enum(ltr,rtl)",
        "padding" => "unit(px,%){1,4}",
        "padding-bottom" => "unit(px,%)",
        "padding-left" => "unit(px,%)",
        "padding-right" => "unit(px,%)",
        "padding-top" => "unit(px,%)",
        "text-align" => "enum(left,center,right)"
      }.freeze

      WRAPPER_ALLOWED_ATTRIBUTES = SECTION_ALLOWED_ATTRIBUTES.merge(
        "full-width" => "enum(full-width)"
      ).freeze

      DEFAULT_ATTRIBUTES = {
        "direction"           => "ltr",
        "padding"             => "20px 0",
        "text-align"          => "center",
        "background-repeat"   => "repeat",
        "background-size"     => "auto",
        "background-position" => "top center"
      }.freeze

      class << self
        def allowed_attributes_for(tag_name)
          tag_name == "mj-wrapper" ? WRAPPER_ALLOWED_ATTRIBUTES : SECTION_ALLOWED_ATTRIBUTES
        end

        def allowed_attributes
          SECTION_ALLOWED_ATTRIBUTES
        end
      end

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

      # ── Background helpers ───────────────────────────────────────────────

      VERTICAL_KEYWORDS   = %w[top bottom].freeze
      HORIZONTAL_KEYWORDS = %w[left right].freeze

      def has_background?(a)
        url = a["background-url"]
        url && !url.to_s.strip.empty?
      end

      def parse_background_position(position_str)
        tokens = position_str.to_s.strip.split(/\s+/)

        case tokens.size
        when 0
          {x: "center", y: "top"}
        when 1
          if VERTICAL_KEYWORDS.include?(tokens[0])
            {x: "center", y: tokens[0]}
          else
            {x: tokens[0], y: "center"}
          end
        when 2
          first, second = tokens
          if VERTICAL_KEYWORDS.include?(first) ||
             (first == "center" && HORIZONTAL_KEYWORDS.include?(second))
            {x: second, y: first}
          else
            {x: first, y: second}
          end
        else
          {x: "center", y: "top"}
        end
      end

      def get_background_position(a)
        base = parse_background_position(a["background-position"] || "top center")
        pos_x = a["background-position-x"]
        pos_y = a["background-position-y"]
        x = (pos_x && !pos_x.to_s.empty?) ? pos_x : base[:x]
        y = (pos_y && !pos_y.to_s.empty?) ? pos_y : base[:y]
        {x: x, y: y}
      end

      def get_background_string(a)
        pos = get_background_position(a)
        "#{pos[:x]} #{pos[:y]}"
      end

      def get_background(a)
        bg_url    = a["background-url"]
        bg_color  = a["background-color"]
        bg_size   = a["background-size"]
        bg_repeat = a["background-repeat"]

        if has_background?(a)
          pos_str = get_background_string(a)
          parts = []
          parts << bg_color if bg_color && !bg_color.to_s.empty?
          parts << "url('#{bg_url}')"
          parts << pos_str
          parts << "/ #{bg_size}"
          parts << bg_repeat
          parts.join(" ")
        else
          bg_color
        end
      end

      # ── VML background for Outlook ───────────────────────────────────────

      PERCENTAGE_RE = /\A\d+(\.\d+)?%\z/

      VML_KEYWORD_TO_PERCENT = {
        "left" => "0%", "top" => "0%",
        "center" => "50%",
        "right" => "100%", "bottom" => "100%"
      }.freeze

      def render_with_background(section_html, a, container_px)
        bg_url    = a["background-url"]
        bg_color  = a["background-color"]
        bg_repeat = a["background-repeat"] || "repeat"
        bg_size   = a["background-size"]   || "auto"
        is_repeat = bg_repeat == "repeat"

        pos = get_background_position(a)

        # Normalize keywords to percentages
        bg_pos_x = VML_KEYWORD_TO_PERCENT.fetch(pos[:x], nil) || (pos[:x] =~ PERCENTAGE_RE ? pos[:x] : "50%")
        bg_pos_y = VML_KEYWORD_TO_PERCENT.fetch(pos[:y], nil) || (pos[:y] =~ PERCENTAGE_RE ? pos[:y] : "0%")

        # Compute VML origin/position per axis
        v_origin_x, v_pos_x = vml_axis_values(bg_pos_x, is_repeat, true)
        v_origin_y, v_pos_y = vml_axis_values(bg_pos_y, is_repeat, false)

        # VML size attributes
        v_size_attrs = vml_size_attributes(bg_size)

        # VML type
        is_auto  = bg_size == "auto"
        vml_type = (!is_repeat && !is_auto) ? "frame" : "tile"

        # Auto special case: force tile, reset position
        if is_auto
          v_origin_x = 0.5; v_pos_x = 0.5
          v_origin_y = 0;   v_pos_y = 0
        end

        # Build v:fill attributes
        fill_pairs = [
          ["origin", "#{v_origin_x}, #{v_origin_y}"],
          ["position", "#{v_pos_x}, #{v_pos_y}"],
          ["src", bg_url],
          ["color", bg_color],
          ["type", vml_type]
        ]
        fill_pairs << ["size", v_size_attrs[:size]] if v_size_attrs[:size]
        fill_pairs << ["aspect", v_size_attrs[:aspect]] if v_size_attrs[:aspect]
        fill_str = fill_pairs.map { |(k, v)| %(#{k}="#{escape_attr(v.to_s)}") }.join(" ")

        %(<!--[if mso | IE]><v:rect style="mso-width-percent:1000;" xmlns:v="urn:schemas-microsoft-com:vml" fill="true" stroke="false"><v:fill #{fill_str} /><v:textbox style="mso-fit-shape-to-text:true" inset="0,0,0,0"><![endif]-->) +
        section_html +
        %(<!--[if mso | IE]></v:textbox></v:rect><![endif]-->)
      end

      def vml_axis_values(pct_str, is_repeat, is_x)
        if pct_str =~ PERCENTAGE_RE
          decimal = pct_str.to_f / 100.0
          if is_repeat
            [decimal, decimal]
          else
            val = (-50 + decimal * 100) / 100.0
            [val, val]
          end
        elsif is_repeat
          [is_x ? 0.5 : 0, is_x ? 0.5 : 0]
        else
          [is_x ? 0 : -0.5, is_x ? 0 : -0.5]
        end
      end

      def vml_size_attributes(bg_size)
        case bg_size
        when "cover"
          {size: "1,1", aspect: "atleast"}
        when "contain"
          {size: "1,1", aspect: "atmost"}
        when "auto"
          {}
        else
          parts = bg_size.to_s.strip.split(/\s+/)
          if parts.size == 1
            {size: bg_size, aspect: "atmost"}
          else
            {size: parts.join(",")}
          end
        end
      end

      # ── mj-section ─────────────────────────────────────────────────────────

      def render_section(node, context, attrs)
        a            = self.class.default_attributes.merge(attrs)
        container_px = parse_px(context[:container_width] || "600px")
        css_class    = a["css-class"]
        bg_color     = a["background-color"]
        border_radius = a["border-radius"]
        bg_has       = has_background?(a)

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

        # Section div, table, td — styles differ based on background-url presence
        border_val = a["border"]
        border_val = nil if border_val.nil? || border_val.to_s.strip.empty? || border_val.to_s.strip == "none"

        if bg_has
          bg_value  = get_background(a)
          bg_string = get_background_string(a)
          bg_repeat = a["background-repeat"]
          bg_size   = a["background-size"]

          div_style = style_join(
            "background"          => bg_value,
            "background-position" => bg_string,
            "background-repeat"   => bg_repeat,
            "background-size"     => bg_size,
            "margin"              => "0px auto",
            "max-width"           => "#{container_px}px"
          )
          table_style = style_join(
            "background"          => bg_value,
            "background-position" => bg_string,
            "background-repeat"   => bg_repeat,
            "background-size"     => bg_size,
            "border-radius"       => border_radius,
            "width"               => "100%"
          )
          td_style = style_join(
            "border"         => border_val,
            "border-top"     => a["border-top"],
            "border-right"   => a["border-right"],
            "border-bottom"  => a["border-bottom"],
            "border-left"    => a["border-left"],
            "border-radius"  => border_radius,
            "direction"      => a["direction"],
            "font-size"      => "0px",
            "padding"        => a["padding"],
            "padding-top"    => a["padding-top"],
            "padding-right"  => a["padding-right"],
            "padding-bottom" => a["padding-bottom"],
            "padding-left"   => a["padding-left"],
            "text-align"     => a["text-align"]
          )
        else
          div_style = style_join(
            "background"       => bg_color,
            "background-color" => bg_color,
            "margin"           => "0px auto",
            "max-width"        => "#{container_px}px"
          )
          table_style = style_join(
            "background"       => bg_color,
            "background-color" => bg_color,
            "border-radius"    => border_radius,
            "width"            => "100%"
          )
          td_style = style_join(
            "border"         => border_val,
            "border-top"     => a["border-top"],
            "border-right"   => a["border-right"],
            "border-bottom"  => a["border-bottom"],
            "border-left"    => a["border-left"],
            "border-radius"  => border_radius,
            "background"     => bg_color,
            "background-color" => bg_color,
            "direction"      => a["direction"],
            "font-size"      => "0px",
            "padding"        => a["padding"],
            "padding-top"    => a["padding-top"],
            "padding-right"  => a["padding-right"],
            "padding-bottom" => a["padding-bottom"],
            "padding-left"   => a["padding-left"],
            "text-align"     => a["text-align"]
          )
        end

        div_attrs = {"class" => css_class, "style" => div_style}
        table_attrs = {
          "align" => "center",
          "background" => bg_has ? a["background-url"] : nil,
          "border" => "0",
          "cellpadding" => "0",
          "cellspacing" => "0",
          "role" => "presentation",
          "style" => table_style,
          "width" => "100%"
        }
        td_attrs = {
          "align" => a["text-align"],
          "bgcolor" => bg_color,
          "style" => td_style
        }
        inner = merge_outlook_conditionals(render_section_columns(node, context, box_width))

        # Wrap in innerDiv when background image is present (prevents Yahoo whitespace gaps)
        inner_content = bg_has ? %(<div style="line-height:0;font-size:0">#{inner}</div>) : inner

        section_html =
          %(<div#{html_attrs(div_attrs)}>) +
          %(<table#{html_attrs(table_attrs)}>) +
          %(<tbody><tr><td#{html_attrs(td_attrs)}>#{inner_content}</td></tr></tbody></table></div>)

        render_after = %(<!--[if mso | IE]></td></tr></table><![endif]-->)

        body = bg_has ? render_with_background(section_html, a, container_px) : section_html

        "#{render_before}\n#{body}\n#{render_after}"
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

        col_parts = with_inherited_mj_class(context, node) do
          columns.each_with_index.map do |col, i|
            col_attrs = resolved_attributes(col, context)
            v_align   = col_attrs["vertical-align"] || "top"
            col_px    = (box_width.to_f * widths[i] / 100.0).round

            td_open  = %(<!--[if mso | IE]><td class="" style="vertical-align:#{v_align};width:#{col_px}px;" ><![endif]-->)
            td_close = %(<!--[if mso | IE]></td><![endif]-->)

            context[:_column_width_pct] = widths[i]
            col_html = render_node(col, context, parent: "mj-section")

            "#{td_open}\n#{col_html}\n#{td_close}"
          end
        end

        ([open_table, open_tr] + col_parts + [close_tr, close_table]).join("\n")
      end

      # ── mj-wrapper ─────────────────────────────────────────────────────────

      def render_wrapper(node, context, attrs)
        a            = self.class.default_attributes.merge(attrs)
        container_px = parse_px(context[:container_width] || "600px")
        css_class    = a["css-class"]
        bg_color     = a["background-color"]
        full_width   = a["full-width"] == "full-width"

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
          "max-width"        => (full_width ? nil : "#{container_px}px")
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
          %(<table align="center" border="0" cellpadding="0" cellspacing="0" role="presentation" style="#{table_style}" width="100%">) +
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

        section_parts = with_inherited_mj_class(context, node) do
          children.map do |child|
            td_open  = %(<!--[if mso | IE]><td class="" width="#{container_px}px" ><![endif]-->)
            td_close = %(<!--[if mso | IE]></td><![endif]-->)
            child_html = render_node(child, context, parent: "mj-wrapper")
            "#{td_open}\n#{child_html}\n#{td_close}"
          end
        end

        ([open_table, open_tr] + section_parts + [close_tr, close_table]).join("\n")
      end
    end
  end
end
