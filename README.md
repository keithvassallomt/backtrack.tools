# backtrack.tools

The website for [Backtrack](https://github.com/keithvassallomt/backtrack). It
is built with [Zola](https://www.getzola.org/) 0.23, a static site generator,
and served from S3 through CloudFront.

The guides, the install page and the changelog are not kept here. They are
fetched from Backtrack's repository at a release tag each time the site is
built, so the site always describes that release.

## What is where

- `config.toml` holds Zola's settings, the home page's title and
  description, and the commands in its Get Backtrack section.
- `templates/` holds the pages' HTML: `base.html` around every page,
  `index.html` the home page, `guides.html` the list of guides, `guide.html`
  a guide (`install.html` the install guide), `changelog.html`, and
  `404.html`. `components.html` has `shot`, which shows a screenshot as WebP.
- `data/` holds what the home page shows that is not prose: the Documents
  folder its opening rewinds through, its five stories, and its day on a
  laptop.
- `static/` is copied into the site as it is: `site.css`, `site.js`, the
  fonts (each under the SIL Open Font License, with its licence beside it),
  the icon, the Friendly Manifesto badges, the picture link previews show,
  and `.well-known/org.friendlyhub.VerifiedApps.txt`, the token by which
  FriendlyHub knows that the app ID `tools.backtrack.Backtrack` belongs to
  whoever runs this domain. `static/screenshots/` holds the pictures
  software centres show beside Backtrack's listing: its metainfo names them,
  so a name, once used, is never removed or renamed.
- `scripts/fetch-docs` writes `content/guides/`, `content/install.md`,
  `content/changelog.md` and `assets/guides/images/` from Backtrack's
  repository. None of them is committed.
- `scripts/check-site` checks the built site: every link within it, the
  sections Backtrack's Preferences link to, the home page's commands against
  the install guide's, and no Unreleased section in the changelog.
- `scripts/check-contrast` computes the contrast of every text colour against
  its background, in the dark and the light style, against WCAG AA.
- `public/` is the built site. It is not committed.
- `infra/provision` makes everything on AWS: a private S3 bucket in
  eu-south-1 that only the CloudFront distribution reads, the distribution
  for `backtrack.tools` and `www.backtrack.tools`, its certificate from ACM,
  and the domain's records in Route 53. A CloudFront Function,
  `infra/www-redirect.js`, sends www to the bare domain, serves a folder's
  address (`/guides/`) from its `index.html`, and adds the slash to an
  address that lacks it. An address with no page gets `404.html`, with the
  status 404. The script records what it has made in `infra/resources.env`,
  so running it again makes nothing twice.
- `infra/deploy` fetches, builds, checks and publishes.

## Working on the site

You need Zola 0.23 (`sudo pacman -S zola` on Arch), Python 3, git and
[just](https://just.systems/).

1. `just fetch-docs main` brings the guides as they are on Backtrack's main
   branch. Without a name it takes the newest release (`v1.2.3`, never a
   release candidate); any tag, branch or commit works.
2. `just serve` shows the site on <http://localhost:1111> and rebuilds it
   whenever a file changes.
3. `just build` builds it into `public/` and runs both checks.

`just deploy` publishes the site: it fetches from the newest release, builds,
checks, and only then uploads, so a failure at any step uploads nothing. It
needs the AWS CLI signed in to the account that holds the domain; nothing else
holds a credential for it. `just provision` makes, or brings back in line,
everything on AWS, and is safe to run again.

## Copy

All of the site's own copy is drafted and then run through the humanizer
skill before it is committed, and it follows two rules: no em dash, and no
sentence that begins with "And". Copy Keith dictates is used exactly as he
gives it.
