# One deploy role per environment, assumed by the WEBSITE repo's workflow.
# Bootstrap owns who can assume it; envs/<env> attaches what it can do
# (bucket, distribution and parameters only exist there).

data "aws_iam_policy_document" "site_deploy_trust" {
  for_each = var.environments

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.oidc_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        for p in local.website_sub_prefixes : "${p}:environment:${each.value.website_github_environment}"
      ]
    }
  }
}

resource "aws_iam_role" "site_deploy" {
  for_each = var.environments

  name                 = "${var.project_name}-${each.key}-site-deploy"
  assume_role_policy   = data.aws_iam_policy_document.site_deploy_trust[each.key].json
  max_session_duration = 3600
}
