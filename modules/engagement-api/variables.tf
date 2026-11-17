variable "name" {
  description = "Resource name prefix, e.g. my-website-prod. Must start with the bootstrap project_name."
  type        = string
}

variable "domain_name" {
  description = "Site apex domain in Cloudflare, e.g. tecssol.uk. The API is served at <api_subdomain>.<domain_name>."
  type        = string
}

variable "cloudflare_zone_name" {
  description = "Cloudflare zone holding domain_name. Null = domain_name itself."
  type        = string
  default     = null
}

variable "api_subdomain" {
  type    = string
  default = "api"
}

variable "site_origins" {
  description = "Browser origins allowed to call the API (CORS) and to render the Turnstile widget."
  type        = list(string)
}

variable "lambda_role_name" {
  description = "Lambda execution role created by bootstrap (CI cannot create IAM roles)."
  type        = string
}

variable "deploy_role_name" {
  description = "Website deploy role (bootstrap). Gets read access to the site config parameters."
  type        = string
}

variable "parameter_prefix" {
  description = "SSM path prefix; site config values are written under <prefix>/site_config/."
  type        = string
}

# Turnstile widget is created by hand in the Cloudflare dashboard: its API
# permission is not available to these tokens. See docs/06.
variable "turnstile_site_key" {
  description = "Turnstile widget site key (public)."
  type        = string
}

variable "turnstile_secret_key" {
  description = "Turnstile widget secret key. Only the Lambda receives it."
  type        = string
  sensitive   = true
}

variable "comments_require_approval" {
  description = "true = new comments are stored as pending and hidden until approved."
  type        = bool
  default     = false
}

variable "throttle_rate_limit" {
  description = "API Gateway steady-state requests per second (whole API)."
  type        = number
  default     = 10
}

variable "throttle_burst_limit" {
  type    = number
  default = 20
}

variable "cloudflare_rate_limit_per_10s" {
  description = "Requests per IP per 10 seconds before Cloudflare blocks that IP for 10 seconds."
  type        = number
  default     = 20
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "web_analytics_token" {
  description = "Cloudflare Web Analytics beacon token (public value, created in the dashboard). Null = analytics off."
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
