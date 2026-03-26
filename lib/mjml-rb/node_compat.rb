require "nokogiri"

module MjmlRb
  module NodeCompat
    def tag_name
      name
    end

    def file
      self["data-mjml-file"]
    end
  end
end

Nokogiri::XML::Node.prepend(MjmlRb::NodeCompat)
