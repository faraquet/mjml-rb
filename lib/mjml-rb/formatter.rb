module MjmlRb
  # A deliberately conservative formatter: tokenize markup before changing
  # whitespace, and never reserialize the document (which can damage VML/MSO).
  class Formatter
    IGNORE = /<!--\s*htmlmin:ignore\s*-->/
    PROTECTED = /<!--\s*htmlmin:ignore\s*-->.*?<!--\s*htmlmin:ignore\s*-->|<(pre|textarea|script|style)\b[^>]*>.*?<\/\1\s*>|<!--[\s\S]*?-->|<v:[\s\S]*?<\/v:[^>]+>/im
    TOKEN = /<[^>"']*(?:(?:"[^"]*"|'[^']*')[^>"']*)*>/m

    def initialize(options)
      @options = options
    end

    def format(html)
      output = html.dup
      # Source and generated protection regions are restored byte for byte.
      regions = []
      prefix = "MJMLRBPRESERVE#{object_id}X"
      prefix += "X" while html.include?(prefix)
      output = output.gsub(/<!--\s*htmlmin:ignore\s*-->.*?<!--\s*htmlmin:ignore\s*-->/m) do |region|
        regions << region.gsub(IGNORE, "")
        "#{prefix}#{regions.length - 1}X"
      end
      raw_regions = []
      output = output.gsub(/<!--mjml-rb:raw-start-->(.*?)<!--mjml-rb:raw-end-->/m) do
        content = Regexp.last_match(1)
        content = process_styles(content) if @options[:sanitize_styles]
        raw_regions << content
        "#{prefix}R#{raw_regions.length - 1}X"
      end
      output = process_styles(output) if @options[:sanitize_styles] || (@options[:minify] && @options[:minify_options].fetch(:minify_css, true))
      if @options[:minify] || @options[:beautify]
        protected = []
        output = output.gsub(PROTECTED) do |part|
          protected << part
          "<#{prefix}P#{protected.length - 1}X/>"
        end
        # Whitespace inside text and quoted attributes is significant. Only
        # whitespace between structural tags is eligible for formatting.
        output = output.gsub(/(>)([\t\r\n ]*)(?=<)/) do
          @options[:minify] ? ">" : ">\n"
        end
        protected.each_with_index { |part, index| output = output.gsub("<#{prefix}P#{index}X/>") { part } }
      end
      raw_regions.each_with_index { |part, index| output = output.gsub("#{prefix}R#{index}X") { part } }
      regions.each_with_index { |part, index| output = output.gsub("#{prefix}#{index}X") { part } }
      output.gsub(IGNORE, "")
    end

    private

    def process_styles(html)
      pattern = /<(script|textarea|pre)\b[^>]*>.*?<\/\1\s*>|<!--.*?-->|(<style\b[^>]*>)(.*?)(<\/style\s*>)|#{TOKEN}/mi
      html.gsub(pattern) do |part|
        if Regexp.last_match(1) || part.start_with?("<!--")
          part
        elsif Regexp.last_match(2)
          opening, css, closing = Regexp.last_match.captures[1..3]
          "#{opening}#{process_css(css)}#{closing}"
        else
          part.gsub(/(\sstyle\s*=\s*)(["'])(.*?)\2/mi) do
            name, quote, css = Regexp.last_match.captures
            "#{name}#{quote}#{process_css(css)}#{quote}"
          end
        end
      end
    end

    def process_css(css)
      variables = []
      kinds = []
      token_prefix = "mjmlrbvariable"
      token_prefix += "x" while css.include?(token_prefix)
      syntaxes = @options[:template_syntax]
      unless syntaxes.is_a?(Array) && syntaxes.all? { |syntax| syntax.is_a?(Hash) && (syntax[:prefix] || syntax['prefix']).is_a?(String) && (syntax[:suffix] || syntax['suffix']).is_a?(String) }
        raise ArgumentError, "template_syntax must be an array of prefix/suffix objects"
      end
      syntaxes.each do |syntax|
        prefix, suffix = syntax.values_at(:prefix, :suffix)
        prefix ||= syntax['prefix']
        suffix ||= syntax['suffix']
        raise ArgumentError, "Template delimiters must not be empty" if prefix.empty? || suffix.empty?
        pattern = /#{Regexp.escape(prefix)}.*?#{Regexp.escape(suffix)}/m
        if @options[:sanitize_styles]
          if css.scan(Regexp.new(Regexp.escape(prefix))).size != css.scan(Regexp.new(Regexp.escape(suffix))).size
            raise ArgumentError, "Unbalanced template delimiters #{prefix.inspect}/#{suffix.inspect} in CSS"
          end
          rest = css.gsub(pattern, '')
          if rest.include?(prefix) || rest.include?(suffix)
            raise ArgumentError, "Unbalanced template delimiters #{prefix.inspect}/#{suffix.inspect} in CSS"
          end
        end
        css = css.gsub(pattern) do |token|
          match = Regexp.last_match
          before, after = css[0...match.begin(0)].rstrip, css[match.end(0)..].lstrip
          kinds << (after.start_with?(':') ? :property : before.end_with?(':') ? :value : :block)
          variables << token
          "#{token_prefix}#{variables.length - 1}token"
        end
      end
      if @options[:sanitize_styles] && !@options[:allow_mixed_syntax] && kinds.include?(:block) && (kinds.include?(:value) || kinds.include?(:property))
        raise ArgumentError, "Mixed variable syntax detected in CSS; set allow_mixed_syntax: true to allow it"
      end
      if @options[:minify] && @options[:minify_options].fetch(:minify_css, true)
        # CSS strings and comments are tokens, not whitespace to collapse.
        css = css.split(/("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\/\*.*?\*\/)/m).map.with_index do |part, index|
          index.odd? ? part : part.gsub(/\s+/, ' ').gsub(/\s*([{};,])\s*/, '\1').gsub(/:\s+/, ':')
        end.join.strip
      end
      variables.each_with_index { |value, index| css = css.gsub("#{token_prefix}#{index}token") { value } }
      css
    end
  end
end
