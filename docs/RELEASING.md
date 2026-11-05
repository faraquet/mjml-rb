# Publishing mjml-rb 0.6.1

Release preparation bumps the version, validates the gem, and creates a draft
GitHub release targeting the release commit. Publishing the GitHub release and
pushing the gem to RubyGems are separate maintainer actions.

Before publishing, review the release commit and its CI results, inspect the
packaged gem, and smoke-test its API and CLI from outside the checkout. Confirm
that the draft targets the intended release commit and includes the matching
`mjml-rb-0.6.1.gem` asset. If the release commit changes, rebuild and replace the
asset and update the draft's target before publishing.

The prepared [release notes](releases/v0.6.1.md) and changelog use 2026-11-05.
Update the date if publication happens later.

From a clean checkout of the reviewed release commit:

```sh
set -e
test -z "$(git status --porcelain)"
test "$(ruby -Ilib -rmjml-rb/version -e 'print MjmlRb::VERSION')" = "0.6.1"
bundle exec rake test
gem build mjml-rb.gemspec
```

After maintainer approval to publish:

```sh
gem push mjml-rb-0.6.1.gem
gh release edit v0.6.1 --repo faraquet/mjml-rb --draft=false --latest
```

Publishing the draft creates its `v0.6.1` tag at the selected target if the tag
does not already exist. `gem push` publishes to RubyGems using the maintainer's
credentials. `MjmlRb::MJML_COMPATIBILITY_VERSION` remains 5.4.1.
