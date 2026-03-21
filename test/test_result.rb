require "minitest/autorun"

require_relative "../lib/mjml-rb"

class ResultTest < Minitest::Test
  def test_initialize_with_defaults
    result = MjmlRb::Result.new
    assert_equal "", result.html
    assert_equal [], result.errors
    assert_equal [], result.warnings
  end

  def test_initialize_with_all_params
    result = MjmlRb::Result.new(
      html: "<html>test</html>",
      errors: [{ message: "error1" }],
      warnings: [{ message: "warn1" }]
    )
    assert_equal "<html>test</html>", result.html
    assert_equal [{ message: "error1" }], result.errors
    assert_equal [{ message: "warn1" }], result.warnings
  end

  def test_html_coerced_to_string
    result = MjmlRb::Result.new(html: nil)
    assert_equal "", result.html
  end

  def test_errors_coerced_to_array
    result = MjmlRb::Result.new(errors: nil)
    assert_equal [], result.errors
  end

  def test_warnings_coerced_to_array
    result = MjmlRb::Result.new(warnings: nil)
    assert_equal [], result.warnings
  end

  def test_success_when_no_errors
    result = MjmlRb::Result.new(errors: [])
    assert result.success?
  end

  def test_not_success_when_errors_present
    result = MjmlRb::Result.new(errors: [{ message: "bad" }])
    refute result.success?
  end

  def test_to_h
    result = MjmlRb::Result.new(
      html: "<p>hi</p>",
      errors: [{ message: "err" }],
      warnings: [{ message: "warn" }]
    )
    hash = result.to_h
    assert_equal "<p>hi</p>", hash[:html]
    assert_equal [{ message: "err" }], hash[:errors]
    assert_equal [{ message: "warn" }], hash[:warnings]
  end

  def test_to_h_with_empty_result
    result = MjmlRb::Result.new
    hash = result.to_h
    assert_equal "", hash[:html]
    assert_equal [], hash[:errors]
    assert_equal [], hash[:warnings]
  end
end
