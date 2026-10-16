# Publishing mjml-rb 0.6.0

The maintainer merges and publishes this release. Preparation does not create a
tag, publish to RubyGems, or create a GitHub release.

Before merging PR #24, confirm all ten CI jobs pass for its final head, inspect
the packaged gem and smoke-test its API and CLI from outside the checkout.
Runtime source under `lib/` and `bin/` must match the downstream-validated
commit `90f646e35968fdca3afda58c1f2891a7f7a290d6` unless a confirmed blocker is
fixed and revalidated. Release documentation and package contents may change.

After merging PR #24, run the following from a clean repository checkout.
The detached checkout selects the PR's exact merge commit even if `main` has
subsequently advanced. The release date in the changelog and prepared
[release notes](releases/v0.6.0.md) is 2026-10-16.

```sh
set -e
test -z "$(git status --porcelain)"
test "$(gh pr view 24 --repo faraquet/mjml-rb --json state --jq .state)" = "MERGED"
git fetch origin main --tags
release_commit=$(gh pr view 24 --repo faraquet/mjml-rb --json mergeCommit --jq .mergeCommit.oid)
git switch --detach "$release_commit"
test "$(ruby -Ilib -rmjml-rb/version -e 'print MjmlRb::VERSION')" = "0.6.0"
gem build mjml-rb.gemspec
git tag -a v0.6.0 -m "mjml-rb 0.6.0"
git push origin refs/tags/v0.6.0
gem push mjml-rb-0.6.0.gem
gh release create v0.6.0 --repo faraquet/mjml-rb --verify-tag --title "mjml-rb 0.6.0" --notes-file docs/releases/v0.6.0.md
```

`gem push` publishes the built artifact to RubyGems using the maintainer's
credentials, as described in the [RubyGems publishing guide](https://guides.rubygems.org/publishing/).
No version bump is needed: the gem version is already 0.6.0, and
`MjmlRb::MJML_COMPATIBILITY_VERSION` remains 5.4.1.
