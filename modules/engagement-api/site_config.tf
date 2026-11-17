# Public values the website needs at deploy time. The website workflow reads
# them and writes assets/site-config.js, so nothing is copied by hand.

locals {
  site_config = merge(
    {
      api_base_url       = "https://${local.api_host}"
      turnstile_site_key = var.turnstile_site_key
    },
    var.web_analytics_token == null ? {} : { web_analytics_token = var.web_analytics_token },
  )
}

resource "aws_ssm_parameter" "site_config" {
  for_each = local.site_config

  name  = "${var.parameter_prefix}/site_config/${each.key}"
  type  = "String"
  value = each.value
}

data "aws_iam_role" "deploy" {
  name = var.deploy_role_name
}

data "aws_iam_policy_document" "deploy_site_config" {
  statement {
    sid       = "ReadSiteConfig"
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = [for p in aws_ssm_parameter.site_config : p.arn]
  }
}

resource "aws_iam_role_policy" "deploy_site_config" {
  name   = "site-config"
  role   = data.aws_iam_role.deploy.name
  policy = data.aws_iam_policy_document.deploy_site_config.json
}
