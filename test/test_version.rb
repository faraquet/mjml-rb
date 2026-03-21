require "minitest/autorun"

require_relative "../lib/mjml-rb"

class VersionTest < Minitest::Test
  def test_version_is_defined
    refute_nil MjmlRb::VERSION
  end

  def test_version_is_frozen_string
    assert_instance_of String, MjmlRb::VERSION
    assert MjmlRb::VERSION.frozen?
  end

  def test_version_matches_semver_format
    assert_match(/\A\d+\.\d+\.\d+\z/, MjmlRb::VERSION)
  end
end
