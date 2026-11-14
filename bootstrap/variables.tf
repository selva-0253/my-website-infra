variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "project_name" {
  description = "Must match project_name in ../site. The apply role may only manage S3 buckets and IAM roles prefixed with this."
  type        = string
  default     = "my-website"
}

variable "infra_repository" {
  description = "The infra GitHub repo (owner/name) whose workflow runs Terraform."
  type        = string
  default     = "selva-0253/my-website-infra"
}

variable "apply_environment" {
  description = "GitHub environment that gates terraform apply (add yourself as required reviewer)."
  type        = string
  default     = "production"
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone the site uses, if any. The apply role gets write access to this zone only."
  type        = string
  default     = null
}

variable "create_github_oidc_provider" {
  description = "Set false if the account already has an OIDC provider for token.actions.githubusercontent.com."
  type        = bool
  default     = true
}
