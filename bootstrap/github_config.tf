# GitHub-side configuration, so nothing is copied into GitHub by hand.
# Credentials (Cloudflare tokens) are the only values set manually.

# ---------------------------------------------------------------- infra repo

resource "github_actions_variable" "infra" {
  for_each = {
    AWS_REGION        = var.aws_region
    TF_STATE_BUCKET   = aws_s3_bucket.tfstate.id
    TF_PLAN_ROLE_ARN  = aws_iam_role.tf_plan.arn
    TF_APPLY_ROLE_ARN = aws_iam_role.tf_apply.arn
  }

  repository    = var.infra_repository
  variable_name = each.key
  value         = each.value
}

resource "github_repository_environment" "infra_apply" {
  for_each = var.environments

  repository  = var.infra_repository
  environment = "infra-${each.key}"

  dynamic "reviewers" {
    for_each = var.require_apply_approval ? [1] : []
    content {
      users = [tonumber(data.github_user.owner.id)]
    }
  }

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "infra_apply" {
  for_each = var.environments

  repository     = var.infra_repository
  environment    = github_repository_environment.infra_apply[each.key].environment
  branch_pattern = var.infra_branch
}

# -------------------------------------------------------------- website repo

resource "github_repository_environment" "website" {
  for_each = var.environments

  repository  = var.website_repository
  environment = each.value.website_github_environment

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "website" {
  for_each = var.environments

  repository     = var.website_repository
  environment    = github_repository_environment.website[each.key].environment
  branch_pattern = each.value.website_branch
}

locals {
  website_variables = merge([
    for env, cfg in var.environments : {
      "${env}/AWS_REGION"            = { env = env, name = "AWS_REGION", value = var.aws_region }
      "${env}/AWS_ROLE_ARN"          = { env = env, name = "AWS_ROLE_ARN", value = aws_iam_role.site_deploy[env].arn }
      "${env}/SITE_PARAMETER_PREFIX" = { env = env, name = "SITE_PARAMETER_PREFIX", value = "/${var.project_name}/${env}" }
    }
  ]...)
}

resource "github_actions_environment_variable" "website" {
  for_each = local.website_variables

  repository    = var.website_repository
  environment   = github_repository_environment.website[each.value.env].environment
  variable_name = each.value.name
  value         = each.value.value
}
