# backtrack.tools: built with Zola into public/, served from S3 through CloudFront.

# Bring the guides, the install page and the changelog from Backtrack at REF (the newest release tag if not given).
fetch-docs REF="":
    scripts/fetch-docs {{REF}}

# Build the site into public/, then check its links, commands and contrast. Needs `just fetch-docs` once.
build:
    @test -f content/install.md || { echo "No guides yet: run 'just fetch-docs' (or 'just fetch-docs main') first."; exit 1; }
    zola build
    scripts/check-site
    scripts/check-contrast > /dev/null || scripts/check-contrast

# Show the site on http://localhost:1111, rebuilt whenever a file changes.
serve:
    @test -f content/install.md || { echo "No guides yet: run 'just fetch-docs' (or 'just fetch-docs main') first."; exit 1; }
    zola serve

# Fetch from the newest release, build, check, then publish to backtrack.tools. Any failure uploads nothing.
deploy:
    infra/deploy

# The contrast of every text colour in both styles, in full.
contrast:
    scripts/check-contrast

# Make, or bring back in line, everything on AWS the site needs. Safe to run again.
provision:
    infra/provision
