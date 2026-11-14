# Custom domain on Cloudflare DNS. Created only when var.domain_name is set.
# All records are DNS-only (grey cloud): ACM must see the validation CNAMEs,
# and CloudFront is already the CDN.

data "cloudflare_zone" "this" {
  count = local.use_domain ? 1 : 0
  filter = {
    name = local.zone_name
  }
}

locals {
  zone_id = local.use_domain ? data.cloudflare_zone.this[0].id : null
}

# CloudFront only accepts certificates from us-east-1.
resource "aws_acm_certificate" "site" {
  count    = local.use_domain ? 1 : 0
  provider = aws.us_east_1

  domain_name               = var.domain_name
  subject_alternative_names = var.include_www ? ["www.${var.domain_name}"] : []
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "cloudflare_dns_record" "cert_validation" {
  for_each = local.use_domain ? {
    for dvo in aws_acm_certificate.site[0].domain_validation_options : dvo.domain_name => dvo
  } : {}

  zone_id = local.zone_id
  name    = trimsuffix(each.value.resource_record_name, ".")
  type    = each.value.resource_record_type
  content = trimsuffix(each.value.resource_record_value, ".")
  ttl     = 1 # automatic
  proxied = false
  comment = "ACM validation for ${var.name}"
}

resource "aws_acm_certificate_validation" "site" {
  count    = local.use_domain ? 1 : 0
  provider = aws.us_east_1

  certificate_arn = aws_acm_certificate.site[0].arn

  depends_on = [cloudflare_dns_record.cert_validation]
}

# Apex + www -> CloudFront. Cloudflare flattens the apex CNAME automatically.
resource "cloudflare_dns_record" "site" {
  for_each = toset(local.aliases)

  zone_id = local.zone_id
  name    = each.value
  type    = "CNAME"
  content = aws_cloudfront_distribution.site.domain_name
  ttl     = 1
  proxied = false
  comment = "${var.name} CloudFront"
}
