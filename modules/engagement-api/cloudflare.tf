# Cloudflare in front of the API. Only api.<domain> is proxied (orange cloud);
# the website records stay DNS-only.
#
# Each cloudflare_ruleset below is the zone's single "entrypoint" ruleset for
# its phase. If rules for a phase were already created in the dashboard,
# creation fails; see docs/06 (troubleshooting) in this repo.

resource "cloudflare_dns_record" "api" {
  zone_id = local.zone_id
  name    = local.api_host
  type    = "CNAME"
  content = aws_apigatewayv2_domain_name.api.domain_name_configuration[0].target_domain_name
  ttl     = 1
  proxied = true
  comment = "${var.name} engagement API (proxied)"
}

# Free plan: 5 custom rules.
resource "cloudflare_ruleset" "firewall" {
  zone_id     = local.zone_id
  kind        = "zone"
  phase       = "http_request_firewall_custom"
  name        = "${var.name} firewall"
  description = "Managed by Terraform (${var.name})"

  rules = [
    {
      description = "API: only GET, POST and CORS preflight"
      action      = "block"
      expression  = "(http.host eq \"${local.api_host}\" and not http.request.method in {\"GET\" \"POST\" \"OPTIONS\"})"
      enabled     = true
    },
    {
      description = "API: only known paths"
      action      = "block"
      expression  = "(http.host eq \"${local.api_host}\" and not starts_with(http.request.uri.path, \"/v1/posts/\") and http.request.uri.path ne \"/v1/cv\")"
      enabled     = true
    },
  ]
}

# Free plan: 1 rule, path field only, IP counting, 10 s period and timeout.
# Only proxied traffic is counted, which here is only the API.
resource "cloudflare_ruleset" "rate_limit" {
  zone_id     = local.zone_id
  kind        = "zone"
  phase       = "http_ratelimit"
  name        = "${var.name} rate limit"
  description = "Managed by Terraform (${var.name})"

  rules = [
    {
      description = "API: per-IP request rate"
      action      = "block"
      expression  = "(http.request.uri.path contains \"/v1/posts/\" or http.request.uri.path eq \"/v1/cv\")"
      enabled     = true
      ratelimit = {
        characteristics     = ["ip.src", "cf.colo.id"]
        period              = 10
        requests_per_period = var.cloudflare_rate_limit_per_10s
        mitigation_timeout  = 10
      }
    },
  ]
}

# Adds the shared secret, proving to the Lambda that the request came through Cloudflare.
resource "cloudflare_ruleset" "request_headers" {
  zone_id     = local.zone_id
  kind        = "zone"
  phase       = "http_request_late_transform"
  name        = "${var.name} request headers"
  description = "Managed by Terraform (${var.name})"

  rules = [
    {
      description = "API: origin verification header"
      action      = "rewrite"
      expression  = "(http.host eq \"${local.api_host}\")"
      enabled     = true
      action_parameters = {
        headers = {
          "x-origin-verify" = {
            operation = "set"
            value     = random_password.origin_secret.result
          }
        }
      }
    },
  ]
}

# Cloudflare -> API Gateway must use HTTPS with a valid certificate.
resource "cloudflare_ruleset" "config" {
  zone_id     = local.zone_id
  kind        = "zone"
  phase       = "http_config_settings"
  name        = "${var.name} config"
  description = "Managed by Terraform (${var.name})"

  rules = [
    {
      description = "API: Full (strict) TLS to origin"
      action      = "set_config"
      expression  = "(http.host eq \"${local.api_host}\")"
      enabled     = true
      action_parameters = {
        ssl = "strict"
      }
    },
  ]
}
