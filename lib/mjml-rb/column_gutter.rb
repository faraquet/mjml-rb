module MjmlRb
  # Port of mjml-column's v5 gutter arithmetic. One immutable layout value is
  # passed to both the normal column and its Outlook cell.
  class ColumnGutter
    def initialize(width:, container_width:, gutter:, count:, index:, direction: "ltr", grouped: false)
      @unit = width.to_s.end_with?("px") ? "px" : "%"
      @width = width.to_f
      @container = container_width.to_f
      @gutter = gutter.to_s
      @count, @index, @rtl, @grouped = count, index, direction == "rtl", grouped
    end

    def desktop_width
      reduced = [(@width - normalized_gutter(@unit) * (@count - 1) / @count).round(6), 0].max
      return reduced if @unit == "%"

      floor = reduced.floor
      extras = [[(@count * (reduced - floor)).round, 0].max, @count].min
      floor + (@index < extras ? 1 : 0)
    end

    def width
      "#{number(desktop_width)}#{@unit}"
    end

    def width_class
      "mj-column-#{@unit == '%' ? 'per' : 'px'}-#{number(desktop_width).tr('.', '-')}"
    end

    def padding_class
      gutter = normalized_gutter(@unit)
      gutter = gutter.round if @unit == "px"
      "mj-column-gutter-#{@count}-#{@index + 1}-#{@unit == '%' ? 'per' : 'px'}-#{number(gutter).tr('.', '-')}#{@rtl ? '-rtl' : ''}"
    end

    def desktop_padding(unit = @unit)
      gutter = normalized_gutter(unit)
      gutter = gutter.round if unit == "px"
      leading = unit == "px" ? (gutter / 2.0).ceil : gutter / 2.0
      trailing = unit == "px" ? (gutter / 2.0).floor : gutter / 2.0
      first, last = @index.zero?, @index == @count - 1
      right = @rtl ? (first ? 0 : trailing) : (last ? 0 : leading)
      left = @rtl ? (last ? 0 : leading) : (first ? 0 : trailing)
      padding([0, right, 0, left], unit)
    end

    def mobile_padding
      return desktop_padding if @grouped
      half = normalized_gutter("%") / 2.0
      padding([@index.zero? ? 0 : half, 0, @index == @count - 1 ? 0 : half, 0], "%")
    end

    def mobile_width
      return "100%" unless @grouped
      percentage = @unit == "%" ? desktop_width : desktop_width / @container * 100
      "#{number(percentage)}%"
    end

    def grouped?
      @grouped
    end

    private

    def normalized_gutter(unit)
      value = @gutter.to_f
      source_unit = @gutter.end_with?("%") ? "%" : "px"
      return value if unit == source_unit
      return 0 if @container.zero?
      unit == "%" ? value / @container * 100 : @container * value / 100
    end

    def padding(values, unit)
      values.map { |value| "#{number(unit == 'px' ? value.round : value)}#{unit}" }.join(" ")
    end

    def number(value)
      value.round(6).to_s.sub(/\.0+$/, "")
    end
  end
end
