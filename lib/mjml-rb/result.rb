module MjmlRb
  class Result
    attr_reader :html, :errors, :warnings, :dependencies

    def initialize(html: "", errors: [], warnings: [], dependencies: [])
      @html = html.to_s
      @errors = Array(errors)
      @warnings = Array(warnings)
      @dependencies = Array(dependencies).freeze
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
