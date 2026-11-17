project_name = "my-website"
environment  = "prod"
aws_region   = "ap-south-1"

domain_name = "tecssol.uk"
include_www = true

# Engagement API (likes and comments) and site extras
# Turnstile widget created by hand (Cloudflare > Turnstile > Add widget, see docs/06).
# The secret key is NOT stored here: it is the repository secret TURNSTILE_SECRET_KEY.
turnstile_site_key        = "0x4AAAAAAGGA6w0b3jpOJCkL"
comments_require_approval = false
budget_email              = "selvarajofficail0253@protonmail.com"
monthly_budget_usd        = 5
# Paste the token from Cloudflare > Web Analytics > Add a site (see docs/06):
# web_analytics_token     = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
