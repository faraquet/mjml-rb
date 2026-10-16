# MJML v5 reference contracts

This private development package pins `mjml@5.4.1`. It is excluded from the gem.
Install it with `npm ci --prefix test/reference --ignore-scripts`, then run
`MJML_REFERENCE=1 bundle exec rake test` to check both compilers.

The section gutter inputs and critical fragments are adapted from the MIT-licensed
[upstream gutter tests](https://github.com/mjmlio/mjml/blob/v5.4.1/packages/mjml/test/section-gutter.test.js).
Other cases focus on the body, social, radius, hero, image and accordion contracts.
`projection.rb` extracts selected DOM attributes/styles, including Outlook-only
tables, so general whitespace and attribute order do not masquerade as differences.

`update.rb` refreshes projections from the pinned JavaScript compiler, never from
Ruby output. Review changes to `v5_cases.json` before committing them. Fragment
assertions are retained exactly except for semantically optional trailing style
semicolons in the Ruby comparison.

Upstream MJML is Copyright (c) Mailjet and distributed under the MIT license;
see [its license](https://github.com/mjmlio/mjml/blob/v5.4.1/LICENSE.md).
