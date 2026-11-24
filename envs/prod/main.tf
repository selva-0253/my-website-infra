locals {
  name = "${var.project_name}-${var.environment}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "site" {
  source = "../../modules/static-site"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
    cloudflare    = cloudflare
  }

  name        = local.name
  domain_name = var.domain_name
  include_www = var.include_www
  price_class = var.price_class

  # Naming contract with bootstrap (iam_deploy.tf / github_config.tf).
  deploy_role_name = "${local.name}-site-deploy"
  parameter_prefix = "/${var.project_name}/${var.environment}"
}

# Likes and comments API at api.<domain_name>, behind Cloudflare.
module "engagement" {
  source = "../../modules/engagement-api"
  count  = var.domain_name == null ? 0 : 1

  name         = local.name
  domain_name  = var.domain_name
  site_origins = [for h in concat([var.domain_name], var.include_www ? ["www.${var.domain_name}"] : []) : "https://${h}"]

  # Naming contract with bootstrap (iam_engagement.tf / iam_deploy.tf).
  lambda_role_name = "${local.name}-engagement-api"
  deploy_role_name = "${local.name}-site-deploy"
  parameter_prefix = "/${var.project_name}/${var.environment}"

  turnstile_site_key        = var.turnstile_site_key
  turnstile_secret_key      = var.turnstile_secret_key
  comments_require_approval = var.comments_require_approval
  private_assets_bucket     = module.site.private_assets_bucket
  web_analytics_token       = var.web_analytics_token
  budget_email              = var.budget_email
  monthly_budget_usd        = var.monthly_budget_usd
}
