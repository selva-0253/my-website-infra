output "site_url" {
  description = "Public URL of the site."
  value       = local.use_domain ? "https://${var.domain_name}" : "https://${aws_cloudfront_distribution.site.domain_name}"
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.site.domain_name
}

# ---- Values to add as secrets in GitHub (Settings > Environments > production) ----

output "github_secret_S3_BUCKET_WEBSITE" {
  value = aws_s3_bucket.site.id
}

output "github_secret_CLOUDFRONT_DISTRIBUTION_ID" {
  value = aws_cloudfront_distribution.site.id
}

output "github_secret_AWS_ROLE_ARN" {
  value = aws_iam_role.github_deploy.arn
}

output "github_secret_AWS_REGION" {
  value = var.aws_region
}
