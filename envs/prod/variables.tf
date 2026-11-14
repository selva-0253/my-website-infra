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
