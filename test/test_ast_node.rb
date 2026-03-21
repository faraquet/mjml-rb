require "minitest/autorun"

require_relative "../lib/mjml-rb"

class AstNodeTest < Minitest::Test
  def test_initialize_with_defaults
    node = MjmlRb::AstNode.new(tag_name: "mj-text")
    assert_equal "mj-text", node.tag_name
    assert_equal({}, node.attributes)
    assert_equal([], node.children)
    assert_nil node.content
    assert_nil node.line
    assert_nil node.file
  end

  def test_initialize_with_all_params
    child = MjmlRb::AstNode.new(tag_name: "#text", content: "hello")
    node = MjmlRb::AstNode.new(
      tag_name: "mj-section",
      attributes: { "padding" => "10px", background: "red" },
      children: [child],
      content: "some content",
      line: 5,
      file: "test.mjml"
    )
    assert_equal "mj-section", node.tag_name
    assert_equal({ "padding" => "10px", "background" => "red" }, node.attributes)
    assert_equal [child], node.children
    assert_equal "some content", node.content
    assert_equal 5, node.line
    assert_equal "test.mjml", node.file
  end

  def test_tag_name_coerced_to_string
    node = MjmlRb::AstNode.new(tag_name: :"mj-body")
    assert_equal "mj-body", node.tag_name
  end

  def test_attributes_keys_coerced_to_strings
    node = MjmlRb::AstNode.new(tag_name: "mj-text", attributes: { padding: "10px", color: "red" })
    assert_equal({ "padding" => "10px", "color" => "red" }, node.attributes)
  end

  def test_text_node
    node = MjmlRb::AstNode.new(tag_name: "#text", content: "Hello world")
    assert node.text?
    refute node.comment?
    refute node.element?
  end

  def test_comment_node
    node = MjmlRb::AstNode.new(tag_name: "#comment", content: " a comment ")
    refute node.text?
    assert node.comment?
    refute node.element?
  end

  def test_element_node
    node = MjmlRb::AstNode.new(tag_name: "mj-column")
    refute node.text?
    refute node.comment?
    assert node.element?
  end

  def test_text_content_on_text_node
    node = MjmlRb::AstNode.new(tag_name: "#text", content: "Hello")
    assert_equal "Hello", node.text_content
  end

  def test_text_content_on_text_node_with_nil_content
    node = MjmlRb::AstNode.new(tag_name: "#text", content: nil)
    assert_equal "", node.text_content
  end

  def test_text_content_recursive
    grandchild = MjmlRb::AstNode.new(tag_name: "#text", content: " world")
    child1 = MjmlRb::AstNode.new(tag_name: "#text", content: "Hello")
    child2 = MjmlRb::AstNode.new(tag_name: "span", children: [grandchild])
    parent = MjmlRb::AstNode.new(tag_name: "div", children: [child1, child2])
    assert_equal "Hello world", parent.text_content
  end

  def test_text_content_empty_when_no_text_children
    node = MjmlRb::AstNode.new(tag_name: "mj-section", children: [])
    assert_equal "", node.text_content
  end

  def test_element_children_filters_text_and_comment_nodes
    text = MjmlRb::AstNode.new(tag_name: "#text", content: "text")
    comment = MjmlRb::AstNode.new(tag_name: "#comment", content: "comment")
    element = MjmlRb::AstNode.new(tag_name: "mj-column")
    parent = MjmlRb::AstNode.new(tag_name: "mj-section", children: [text, comment, element])
    assert_equal [element], parent.element_children
  end

  def test_element_children_is_memoized
    element = MjmlRb::AstNode.new(tag_name: "mj-column")
    parent = MjmlRb::AstNode.new(tag_name: "mj-section", children: [element])
    first_call = parent.element_children
    second_call = parent.element_children
    assert_same first_call, second_call
  end

  def test_children_coerced_to_array
    node = MjmlRb::AstNode.new(tag_name: "mj-section", children: nil)
    assert_equal [], node.children
  end
end
