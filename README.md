# backtrack.tools

The website for [Backtrack](https://github.com/keithvassallomt/backtrack),
for now a page saying it is coming soon.

## What is where

- `site/` is the site, as served: `index.html`, the app's icon, and
  `.well-known/org.friendlyhub.VerifiedApps.txt`, the token by which
  FriendlyHub knows that the app ID `tools.backtrack.Backtrack` belongs to
  whoever runs this domain.
- `infra/provision` makes everything on AWS: a private S3 bucket in
  eu-south-1 that only the CloudFront distribution reads, the distribution
  for `backtrack.tools` and `www.backtrack.tools` (a CloudFront Function,
  `infra/www-redirect.js`, sends www to the bare domain), its certificate
  from ACM, and the domain's records in Route 53. It records what it has
  made in `infra/resources.env`, so running it again makes nothing twice.
- `infra/deploy` publishes `site/`.

## Changing the site

Edit `site/`, then `just deploy`. It needs the AWS CLI signed in to the
account that holds the domain; nothing else holds a credential for it.
