require_relative "base"

module MjmlRb
  module Components
    class CarouselImage < Base
      TAGS = ["mj-carousel-image"].freeze

      ALLOWED_ATTRIBUTES = {
        "alt" => "string",
        "href" => "string",
        "rel" => "string",
        "target" => "string",
        "title" => "string",
        "src" => "string",
        "thumbnails-src" => "string",
        "border-radius" => "unit(px,%){1,4}",
        "tb-border" => "string",
        "tb-border-radius" => "unit(px,%){1,4}"
      }.freeze

      DEFAULT_ATTRIBUTES = {
        "alt" => "",
        "target" => "_blank"
      }.freeze

      def render(tag_name:, node:, context:, attrs:, parent:)
        render_item(
          node,
          attrs: DEFAULT_ATTRIBUTES.merge(attrs),
          index: 0,
          container_width: parse_pixel_value(context[:container_width] || "600px"),
          visible: true
        )
      end

      def render_radio(index:, carousel_id:)
        input_attrs = {
          "class" => "mj-carousel-radio mj-carousel-#{carousel_id}-radio mj-carousel-#{carousel_id}-radio-#{index + 1}",
          "checked" => (index.zero? ? "checked" : nil),
          "type" => "radio",
          "name" => "mj-carousel-radio-#{carousel_id}",
          "id" => "mj-carousel-#{carousel_id}-radio-#{index + 1}",
          "style" => style_join(
            "display" => "none",
            "mso-hide" => "all"
          )
        }

        %(<input#{html_attrs(input_attrs)} />)
      end

      def render_thumbnail(node, attrs:, index:, carousel_id:, thumbnails:, tb_width:)
        a = DEFAULT_ATTRIBUTES.merge(attrs)
        css_class = suffix_css_classes(a["css-class"], "thumbnail")
        link_classes = [
          "mj-carousel-thumbnail",
          "mj-carousel-#{carousel_id}-thumbnail",
          "mj-carousel-#{carousel_id}-thumbnail-#{index + 1}",
          css_class
        ].compact.reject(&:empty?).join(" ")

        link_attrs = {
          "style" => style_join(
            "border" => a["tb-border"],
            "border-radius" => a["tb-border-radius"],
            "display" => (thumbnails == "supported" ? "none" : "inline-block"),
            "overflow" => "hidden",
            "width" => tb_width
          ),
          "href" => "##{index + 1}",
          "target" => a["target"],
          "class" => link_classes
        }
        label_attrs = {
          "for" => "mj-carousel-#{carousel_id}-radio-#{index + 1}"
        }
        image_attrs = {
          "style" => style_join(
            "display" => "block",
            "width" => "100%",
            "height" => "auto"
          ),
          "src" => a["thumbnails-src"] || a["src"],
          "alt" => a["alt"],
          "width" => parse_pixel_value(tb_width).to_i.to_s
        }

        <<~HTML.chomp
          <a#{html_attrs(link_attrs)}>
            <label#{html_attrs(label_attrs)}>
              <img#{html_attrs(image_attrs)} />
            </label>
          </a>
        HTML
      end

      def render_item(node, attrs:, index:, container_width:, visible:)
        a = DEFAULT_ATTRIBUTES.merge(attrs)
        css_class = a["css-class"].to_s
        classes = ["mj-carousel-image", "mj-carousel-image-#{index + 1}", css_class].reject(&:empty?).join(" ")
        div_style = visible ? nil : style_join("display" => "none", "mso-hide" => "all")
        img_attrs = {
          "title" => a["title"],
          "src" => a["src"],
          "alt" => a["alt"],
          "style" => style_join(
            "border-radius" => a["border-radius"],
            "display" => "block",
            "width" => "#{container_width.to_i}px",
            "max-width" => "100%",
            "height" => "auto"
          ),
          "width" => container_width.to_i.to_s,
          "border" => "0"
        }
        image_tag = "<img#{html_attrs(img_attrs)} />"

        content = if a["href"]
                    link_attrs = {
                      "href" => a["href"],
                      "rel" => a["rel"],
                      "target" => a["target"] || "_blank"
                    }
                    %(<a#{html_attrs(link_attrs)}>#{image_tag}</a>)
                  else
                    image_tag
                  end

        %(<div#{html_attrs("class" => classes, "style" => div_style)}>#{content}</div>)
      end

      private

      def parse_pixel_value(value)
        matched = value.to_s.match(/(-?\d+(?:\.\d+)?)/)
        matched ? matched[1].to_f : 0.0
      end

      def suffix_css_classes(classes, suffix)
        return nil if classes.nil? || classes.empty?

        classes.split(/\s+/).map { |klass| "#{klass}-#{suffix}" }.join(" ")
      end

    end
  end
end
