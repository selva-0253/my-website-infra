output "site_url" {
  value = local.use_domain ? "https://${var.domain_name}" : "https://${aws_cloudfront_distribution.site.domain_name}"
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.site.domain_name
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.site.id
}

output "site_bucket" {
  value = aws_s3_bucket.site.id
}

output "private_assets_bucket" {
  description = "Private bucket for the profile photo (public/) and CV (private/)."
  value       = aws_s3_bucket.private_assets.id
}

output "private_assets_bucket_arn" {
  value = aws_s3_bucket.private_assets.arn
}
