module MJML
  class Migrator
    TAG_RENAMES = {
      "mj-container" => "mj-body"
    }.freeze

    def migrate(mjml)
      output = mjml.to_s.dup

      TAG_RENAMES.each do |from, to|
        output.gsub!("<#{from}", "<#{to}")
        output.gsub!("</#{from}>", "</#{to}>")
      end

      output
    end
  end
end
