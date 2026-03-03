module MJML
  class Result
    attr_reader :html, :errors, :warnings

    def initialize(html: "", errors: [], warnings: [])
      @html = html.to_s
      @errors = Array(errors)
      @warnings = Array(warnings)
    end

    def success?
      @errors.empty?
    end

    def to_h
      {
        html: @html,
        errors: @errors,
        warnings: @warnings
      }
    end
  end
end
