# Committed on purpose: nothing here is secret, and CI needs it.

aws_region   = "ap-south-1"
project_name = "my-website"
environment  = "prod"

# Optional custom domain (needs an existing Route 53 hosted zone).
#domain_name    = "tecssol.uk"
#hosted_zone_id = "Z0123456789ABCDEFGHIJ"
include_www    = true

# Website repo + environment allowed to upload site content.
github_repository  = "selva-0253/my-website"
github_environment = "production"
