require "minitest/autorun"
require "json"
require "open3"
require_relative "../lib/mjml-rb"
require_relative "reference/projection"

class V5ReferenceTest < Minitest::Test
  CASES = JSON.parse(File.read(File.join(__dir__, "reference/v5_cases.json")))

  CASES.each do |entry|
    define_method("test_#{entry.fetch('name').tr('-', '_')}") do
      result = MjmlRb::Compiler.new.compile(entry.fetch("source"), entry.fetch("options"))
      assert_empty result.errors
      assert_empty result.warnings
      assert_equal entry["expected"], ReferenceProjection.call(result.html, entry["checks"]) if entry["checks"]
      entry.fetch("fragments").each do |fragment|
        assert result.html.gsub(/;"/, '"').include?(fragment.gsub(/;"/, '"')), "Missing v5 reference fragment: #{fragment}"
      end
    end
  end

  # CI runs this with the exact locked npm reference; ordinary Ruby installs
  # exercise the checked-in contracts without needing Node at runtime.
  def test_reference_contracts_against_pinned_upstream
    skip "Set MJML_REFERENCE=1 after npm ci --prefix test/reference" unless ENV["MJML_REFERENCE"] == "1"
    input = CASES.map { |entry| JSON.generate(source: entry["source"], options: entry["options"]) }.join("\n") + "\n"
    output, error, status = Open3.capture3("node", File.join(__dir__, "reference/render.cjs"), stdin_data: input)
    assert status.success?, error
    results = output.lines.map { |line| JSON.parse(line) }
    assert_equal CASES.size, results.size
    CASES.zip(results).each do |entry, result|
      assert_empty result["errors"], entry["name"]
      assert_equal entry["expected"], ReferenceProjection.call(result["html"], entry["checks"]) if entry["checks"]
      entry["fragments"].each do |fragment|
        assert result["html"].include?(fragment), "Upstream #{entry['name']} missing #{fragment}"
      end
    end
  end
end
