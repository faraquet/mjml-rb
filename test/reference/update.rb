# Regenerate semantic projections from the pinned upstream compiler only.
require "json"
require "open3"
require_relative "projection"
path = File.join(__dir__, "v5_cases.json")
cases = JSON.parse(File.read(path))
input = cases.map { |entry| JSON.generate(source: entry["source"], options: entry["options"]) }.join("\n") + "\n"
output, error, status = Open3.capture3("node", File.join(__dir__, "render.cjs"), stdin_data: input)
abort error unless status.success?
results = output.lines.map { |line| JSON.parse(line) }
abort "Incomplete oracle output" unless results.size == cases.size
cases.zip(results).each do |entry, result|
  abort "#{entry['name']}: #{result['errors']}" unless result["errors"].empty?
  entry["expected"] = ReferenceProjection.call(result["html"], entry["checks"]) if entry["checks"]
end
File.write(path, JSON.pretty_generate(cases) + "\n")
