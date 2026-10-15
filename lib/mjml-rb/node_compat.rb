require "nokogiri"

module MjmlRb
  module NodeCompat
    def tag_name
      name
    end

    def line
      element? && self["data-mjml-line"] ? self["data-mjml-line"].to_i : super
    end

    def file
      self["data-mjml-file"]
    end
  end
end

Nokogiri::XML::Node.prepend(MjmlRb::NodeCompat)
