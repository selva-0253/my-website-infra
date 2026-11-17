# Likes and comments for the blog.
#
#   Browser ──► api.<domain> (Cloudflare proxy: rate limit, firewall, secret header)
#           ──► API Gateway HTTP API (custom domain only, throttled)
#           ──► Lambda ──► DynamoDB
#
# Requests that do not carry the secret header Cloudflare adds are rejected by
# the Lambda, so going around Cloudflare to the AWS address does not work.

data "cloudflare_zone" "this" {
  filter = {
    name = coalesce(var.cloudflare_zone_name, var.domain_name)
  }
}

locals {
  zone_id    = data.cloudflare_zone.this.id
  api_host   = "${var.api_subdomain}.${var.domain_name}"
  site_hosts = [for o in var.site_origins : trimprefix(o, "https://")]
}

# Shared secret: Cloudflare adds it to every request; the Lambda requires it.
# Also keys the HMAC that turns visitor IPs into anonymous like markers.
resource "random_password" "origin_secret" {
  length  = 48
  special = false
}
