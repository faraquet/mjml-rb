require "nokogiri"

module ReferenceProjection
  def self.call(html, checks)
    checks.map do |check|
      source = if check["outlook"]
                 html.scan(/<!--\[if (?:mso|IE)[^\]]*\]>(.*?)<!\[endif\]-->/m).flatten.join
               else
                 html
               end
      dom = Nokogiri::HTML(source)
      dom.css(check.fetch("selector")).map do |node|
        value = {}
        Array(check["attributes"]).each { |name| value[name] = node[name] }
        Array(check["styles"]).each do |name|
          declarations = node["style"].to_s.split(';').filter_map do |declaration|
            property, setting = declaration.split(':', 2)
            setting&.strip if property.strip == name
          end
          value["style:#{name}"] = declarations.last
        end
        value["text"] = node.text.strip if check["text"]
        value
      end
    end
  end
end
