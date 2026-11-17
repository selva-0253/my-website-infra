variable "project_name" {
  description = "Must equal project_name in bootstrap."
  type        = string
}

variable "environment" {
  description = "Must equal this folder's name and a key of `environments` in bootstrap."
  type        = string
}

variable "aws_region" {
  type = string
}

variable "domain_name" {
  description = "Custom domain in Cloudflare. Null = CloudFront URL only."
  type        = string
  default     = null
}

variable "include_www" {
  type    = bool
  default = true
}

variable "price_class" {
  type    = string
  default = "PriceClass_200"
}

variable "turnstile_site_key" {
  description = "Turnstile widget site key (public), from the Cloudflare dashboard."
  type        = string

  validation {
    condition     = can(regex("^0x[0-9A-Za-z_-]{10,}$", var.turnstile_site_key))
    error_message = "Set turnstile_site_key in terraform.tfvars to the widget's site key (starts with 0x). See docs/06."
  }
}

variable "turnstile_secret_key" {
  description = "Turnstile widget secret key. Set by CI from the TURNSTILE_SECRET_KEY repository secret."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.turnstile_secret_key) > 10
    error_message = "turnstile_secret_key is empty: add the TURNSTILE_SECRET_KEY repository secret in GitHub. See docs/06."
  }
}

variable "comments_require_approval" {
  description = "true = new comments stay hidden until approved (see docs/06)."
  type        = bool
  default     = false
}

variable "web_analytics_token" {
  description = "Cloudflare Web Analytics beacon token (public). Null = no analytics."
  type        = string
  default     = null
}

variable "budget_email" {
  description = "Email for AWS cost alerts. Null = no budget."
  type        = string
  default     = null
}

variable "monthly_budget_usd" {
  type    = number
  default = 5
}
