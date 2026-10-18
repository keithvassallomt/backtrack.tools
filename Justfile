# backtrack.tools: the site in site/, served from S3 through CloudFront.

# Publish site/ to backtrack.tools.
deploy:
    infra/deploy

# Make, or bring back in line, everything on AWS the site needs. Safe to run again.
provision:
    infra/provision
