require 'mjml-rb'
font_options = {
  enabled: {},
  disabled: {fonts: MjmlRb::Renderer::DEFAULT_FONTS.transform_values { nil }}
}
[1, 30].each do |count|
  source = '<mjml><mj-body>' + ('<mj-section><mj-column><mj-text>Hello <b>world</b></mj-text><mj-image src="image.png"/></mj-column></mj-section>' * count) + '</mj-body></mjml>'
  font_options.each do |mode, options|
    compiler = MjmlRb::Compiler.new(options)
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
    puts "sections=#{count} fonts=#{mode} ms/compile=#{(elapsed * 1000 / iterations).round(2)} allocations/compile=#{(GC.stat(:total_allocated_objects) - before) / iterations}"
  end
end
