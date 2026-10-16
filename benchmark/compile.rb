require 'mjml-rb'
compiler = MjmlRb::Compiler.new
[1, 30].each do |count|
  source = '<mjml><mj-body>' + ('<mj-section><mj-column><mj-text>Hello <b>world</b></mj-text><mj-image src="image.png"/></mj-column></mj-section>' * count) + '</mj-body></mjml>'
  3.times { compiler.compile(source) }
  GC.start
  before = GC.stat(:total_allocated_objects)
  iterations = count == 1 ? 300 : 30
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  iterations.times do
    result = compiler.compile(source)
    abort result.errors.inspect unless result.errors.empty?
  end
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  puts "sections=#{count} ms/compile=#{(elapsed * 1000 / iterations).round(2)} allocations/compile=#{(GC.stat(:total_allocated_objects) - before) / iterations}"
end
