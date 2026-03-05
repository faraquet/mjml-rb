require_relative "base"

module MjmlRb
  module Components
    class Text < Base
      TAGS = ["mj-text"].freeze

      DEFAULTS = {
        "align" => "left",
        "color" => "#000000",
        "font-family" => "Ubuntu, Helvetica, Arial, sans-serif",
        "font-size" => "13px",
        "line-height" => "1",
        "padding" => "10px 25px"
      }.freeze

      def tags
        TAGS
      end

      def render(tag_name:, node:, context:, attrs:, parent:)
        a = DEFAULTS.merge(attrs)
        height = a["height"]

        outer_td_style = style_join(
          "background" => a["container-background-color"],
          "font-size" => "0px",
          "padding" => a["padding"],
          "padding-top" => a["padding-top"],
          "padding-right" => a["padding-right"],
          "padding-bottom" => a["padding-bottom"],
          "padding-left" => a["padding-left"],
          "word-break" => "break-word"
        )
        outer_td_attrs = {
          "align" => a["align"],
          "vertical-align" => a["vertical-align"],
          "class" => a["css-class"],
          "style" => outer_td_style
        }

        div_style = style_join(
          "font-family" => a["font-family"],
          "font-size" => a["font-size"],
          "font-style" => a["font-style"],
          "font-weight" => a["font-weight"],
          "letter-spacing" => a["letter-spacing"],
          "line-height" => a["line-height"],
          "text-align" => a["align"],
          "text-decoration" => a["text-decoration"],
          "text-transform" => a["text-transform"],
          "color" => a["color"],
          "height" => height
        )

        content = html_inner(node)
        inner_div = %(<div style="#{div_style}">#{content}</div>)

        body = if height
                 outlook_open = %(<!--[if mso | IE]><table role="presentation" border="0" cellpadding="0" cellspacing="0"><tr><td height="#{escape_attr(height)}" style="vertical-align:top;height:#{escape_attr(height)};"><![endif]-->)
                 outlook_close = %(<!--[if mso | IE]></td></tr></table><![endif]-->)
                 "#{outlook_open}#{inner_div}#{outlook_close}"
               else
                 inner_div
               end

        %(<tr><td#{html_attrs(outer_td_attrs)}>#{body}</td></tr>)
      end
    end
  end
end
