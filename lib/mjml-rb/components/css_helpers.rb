module MjmlRb
  module Components
    # Shared CSS utility methods used by multiple components.
    # Extracted from Button, Image, Divider, and Section to eliminate
    # duplicated logic.
    module CssHelpers
      # Extracts a value from a CSS shorthand property (padding, margin).
      # Follows CSS shorthand rules:
      #   1 value  → all sides
      #   2 values → vertical | horizontal
      #   3 values → top | horizontal | bottom
      #   4 values → top | right | bottom | left
      def shorthand_value(parts, side)
        case parts.length
        when 1 then parts[0]
        when 2, 3 then parts[1]
        when 4 then side == :left ? parts[3] : parts[1]
        else "0"
        end
      end

      # Extracts the numeric border width (in px) from a CSS border shorthand
      # string like "2px solid #000". Returns a Float for sub-pixel values,
      # or 0 when the border is nil, empty, "none", or has no px unit.
      def parse_border_width(border_str)
        return 0 if border_str.nil? || border_str.to_s.strip.empty? || border_str.to_s.strip == "none"

        match = border_str.to_s.match(/(\d+(?:\.\d+)?)\s*px/)
        match ? match[1].to_f : 0
      end
    end
  end
end
