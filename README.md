# backtrack.tools

The website for [Backtrack](https://github.com/keithvassallomt/backtrack),
for now a page saying it is coming soon. It is built with
[Zola](https://www.getzola.org/), a static site generator, and served from S3
through CloudFront.

## What is where

- `config.toml` holds Zola's settings.
- `templates/` holds the pages' HTML. `index.html` is the home page and
  `404.html` the page for an address that does not exist.
- `content/` holds the pages' text, in Markdown.
- `static/` is copied into the site as it is: the app's icon, and
  `.well-known/org.friendlyhub.VerifiedApps.txt`, the token by which
  FriendlyHub knows that the app ID `tools.backtrack.Backtrack` belongs to
  whoever runs this domain.
- `public/` is the built site. It is not committed.
- `infra/provision` makes everything on AWS: a private S3 bucket in
  eu-south-1 that only the CloudFront distribution reads, the distribution
  for `backtrack.tools` and `www.backtrack.tools`, its certificate from ACM,
  and the domain's records in Route 53. A CloudFront Function,
  `infra/www-redirect.js`, sends www to the bare domain, serves a folder's
  address (`/guides/`) from its `index.html`, and adds the slash to an
  address that lacks it. An address with no page gets `404.html`, with the
  status 404. The script records
  what it has made in `infra/resources.env`, so running it again makes
  nothing twice.
- `infra/deploy` builds the site and publishes `public/`.

## Working on the site

You need Zola (`sudo pacman -S zola` on Arch) and [just](https://just.systems/).

- `just serve` shows the site on <http://localhost:1111> and rebuilds it
  whenever a file changes.
- `just build` builds it into `public/`.
- `just deploy` builds it and publishes it to backtrack.tools. A build that
  fails stops before anything is uploaded. Deploying needs the AWS CLI signed
  in to the account that holds the domain; nothing else holds a credential
  for it.
- `just provision` makes, or brings back in line, everything on AWS. It is
  safe to run again.
