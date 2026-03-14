require "minitest/autorun"
require "open3"
require "rbconfig"

class RailtieTest < Minitest::Test
  def test_direct_require_is_safe_without_rails
    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby,
      "-e",
      'require_relative "lib/mjml-rb/railtie"; puts "ok"',
      chdir: File.expand_path("..", __dir__),
    )

    assert status.success?, stderr
    assert_equal "ok\n", stdout
  end
end
