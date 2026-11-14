# All account/repo-specific values are supplied in terraform.tfvars.

variable "aws_region" {
  description = "Region for the Terraform state bucket (and default region for CI)."
  type        = string
}

variable "project_name" {
  description = "Prefix for all AWS resources. CI may only manage resources that start with it."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}$", var.project_name))
    error_message = "project_name must be lowercase letters, digits and hyphens."
  }
}

variable "github_owner" {
  description = "GitHub user that owns both repositories."
  type        = string
}

variable "infra_repository" {
  description = "Name (without owner) of the repo that runs Terraform."
  type        = string
}

variable "website_repository" {
  description = "Name (without owner) of the repo that holds the site content."
  type        = string
}

variable "infra_branch" {
  description = "Branch of the infra repo that may plan and apply."
  type        = string
  default     = "main"
}

variable "environments" {
  description = <<-EOT
    Deployment environments. The key must match a folder in envs/ and creates:
      - GitHub environment "infra-<key>" in the infra repo (gates terraform apply)
      - IAM role "<project>-<key>-site-deploy" for the website repo
      - GitHub environment <website_github_environment> in the website repo
  EOT
  type = map(object({
    website_github_environment = string
    website_branch             = optional(string, "main")
  }))

  validation {
    condition     = length(var.environments) > 0
    error_message = "Define at least one environment."
  }
}

variable "require_apply_approval" {
  description = "Add the repo owner as required reviewer on infra-<env>. Needs a public repo or a paid GitHub plan."
  type        = bool
  default     = true
}

variable "create_github_oidc_provider" {
  description = "Set false if the AWS account already has an OIDC provider for token.actions.githubusercontent.com."
  type        = bool
  default     = true
}
