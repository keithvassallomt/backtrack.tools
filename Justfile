# backtrack.tools: built with Zola into public/, served from S3 through CloudFront.

# Build the site into public/.
build:
    zola build

# Show the site on http://localhost:1111, rebuilt whenever a file changes.
serve:
    zola serve

# Build the site, then publish it to backtrack.tools. A failed build uploads nothing.
deploy:
    infra/deploy

# Make, or bring back in line, everything on AWS the site needs. Safe to run again.
provision:
    infra/provision
