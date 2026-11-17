output "site_url" {
  value = module.site.site_url
}

output "cloudfront_domain_name" {
  value = module.site.cloudfront_domain_name
}

output "cloudfront_distribution_id" {
  value = module.site.cloudfront_distribution_id
}

output "site_bucket" {
  value = module.site.site_bucket
}

output "api_base_url" {
  value = one(module.engagement[*].api_base_url)
}
