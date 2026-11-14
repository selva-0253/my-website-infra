variable "aws_region" {
  description = "Region for the S3 bucket and IAM resources."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Short name used to prefix resources."
  type        = string
  default     = "my-website"
}

variable "environment" {
  description = "Environment name (used in tags and names)."
  type        = string
  default     = "prod"
}

variable "bucket_name" {
  description = "Globally unique S3 bucket name for site content. Leave null to auto-generate."
  type        = string
  default     = null
}

# ---------- Custom domain (optional) ----------

variable "domain_name" {
  description = "Apex domain to serve the site on, e.g. example.com. Leave null to use the *.cloudfront.net URL only."
  type        = string
  default     = null
}

variable "include_www" {
  description = "Also serve www.<domain_name> (and add it to the certificate)."
  type        = bool
  default     = true
}

variable "hosted_zone_id" {
  description = "Existing Route 53 hosted zone ID for domain_name. Required when domain_name is set."
  type        = string
  default     = null

  validation {
    condition     = var.domain_name == null || var.hosted_zone_id != null
    error_message = "hosted_zone_id must be set when domain_name is set."
  }
}

# ---------- CloudFront ----------

variable "price_class" {
  description = "CloudFront price class. PriceClass_200 includes India; PriceClass_100 is NA/EU only."
  type        = string
  default     = "PriceClass_200"
}

# ---------- GitHub Actions OIDC ----------

variable "github_repository" {
  description = "Website repo allowed to deploy site content, as owner/name."
  type        = string
  default     = "selva-0253/my-website"
}

variable "github_branch" {
  description = "Branch allowed to assume the deploy role."
  type        = string
  default     = "main"
}

variable "github_environment" {
  description = "GitHub Actions environment the deploy job runs in (deploy.yml uses `production`). Set null to trust by branch instead."
  type        = string
  default     = "production"
}
