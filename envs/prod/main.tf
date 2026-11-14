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
