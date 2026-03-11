module MjmlRb
  class AstNode
    attr_reader :tag_name, :attributes, :children, :content, :line, :file

    def initialize(tag_name:, attributes: {}, children: [], content: nil, line: nil, file: nil)
      @tag_name = tag_name.to_s
      @attributes = attributes.transform_keys(&:to_s)
      @children = Array(children)
      @content = content
      @line = line
      @file = file
    end

    def text?
      @tag_name == "#text"
    end

    def comment?
      @tag_name == "#comment"
    end

    def element?
      !text? && !comment?
    end

    def text_content
      return @content.to_s if text?
      @children.map(&:text_content).join
    end

    def element_children
      @children.select(&:element?)
    end
  end
end
