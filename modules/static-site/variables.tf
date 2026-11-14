variable "name" {
  description = "Resource name prefix, e.g. my-website-prod. Must start with the bootstrap project_name."
  type        = string
}

variable "bucket_name" {
  description = "Content bucket name. Null = <name>-site-<account id>."
  type        = string
  default     = null
}

variable "domain_name" {
  description = "Custom domain (apex) hosted in Cloudflare. Null = serve on *.cloudfront.net only."
  type        = string
  default     = null
}

variable "include_www" {
  description = "Also serve www.<domain_name>."
  type        = bool
  default     = true
}

variable "cloudflare_zone_name" {
  description = "Cloudflare zone holding domain_name. Null = domain_name itself."
  type        = string
  default     = null
}

variable "price_class" {
  description = "CloudFront price class. PriceClass_200 includes India."
  type        = string
  default     = "PriceClass_200"
}

variable "deploy_role_name" {
  description = "IAM role (created by bootstrap) the website repo uses to publish content."
  type        = string
}

variable "parameter_prefix" {
  description = "SSM Parameter Store path where the website workflow reads bucket and distribution IDs."
  type        = string
}
