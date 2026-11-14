# OIDC provider + the two roles the infra repo's workflow uses.

resource "aws_iam_openid_connect_provider" "github" {
  count          = var.create_github_oidc_provider ? 1 : 0
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

locals {
  oidc_arn = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn

  site_bucket_arn  = "arn:aws:s3:::${var.project_name}-*"
  ssm_param_arn    = "arn:aws:ssm:*:${local.account_id}:parameter/${var.project_name}/*"
  deploy_role_arns = [for r in aws_iam_role.site_deploy : r.arn]
}

# ------------------------------------------------------------------ plan role
# Read-only. Usable from pull requests and from the infra branch.

data "aws_iam_policy_document" "plan_trust" {
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
      values = flatten([for p in local.infra_sub_prefixes : [
        "${p}:pull_request",
        "${p}:ref:refs/heads/${var.infra_branch}",
      ]])
    }
  }
}

resource "aws_iam_role" "tf_plan" {
  name               = "${var.project_name}-tf-plan"
  assume_role_policy = data.aws_iam_policy_document.plan_trust.json
}

data "aws_iam_policy_document" "plan" {
  statement {
    sid = "ReadSiteResources"
    actions = [
      "s3:Get*", "s3:List*",
      "cloudfront:Get*", "cloudfront:List*", "cloudfront:Describe*",
      "acm:Describe*", "acm:List*", "acm:Get*",
      "iam:Get*", "iam:List*",
      "ssm:DescribeParameters",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "ReadSiteParameters"
    actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:ListTagsForResource"]
    resources = [local.ssm_param_arn]
  }

  # plan takes the state lock, which writes and deletes a .tflock object.
  statement {
    sid       = "StateLock"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.tfstate.arn}/*.tflock"]
  }
}

resource "aws_iam_role_policy" "tf_plan" {
  name   = "terraform-plan"
  role   = aws_iam_role.tf_plan.id
  policy = data.aws_iam_policy_document.plan.json
}

# ----------------------------------------------------------------- apply role
# Only jobs running in a GitHub environment "infra-<env>" can assume it.

data "aws_iam_policy_document" "apply_trust" {
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
      values = flatten([for p in local.infra_sub_prefixes : [
        for env in keys(var.environments) : "${p}:environment:infra-${env}"
      ]])
    }
  }
}

resource "aws_iam_role" "tf_apply" {
  name               = "${var.project_name}-tf-apply"
  assume_role_policy = data.aws_iam_policy_document.apply_trust.json
}

data "aws_iam_policy_document" "apply" {
  source_policy_documents = [data.aws_iam_policy_document.plan.json]

  statement {
    sid       = "StateReadWrite"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.tfstate.arn}/*"]
  }

  statement {
    sid       = "ManageSiteBuckets"
    actions   = ["s3:*"]
    resources = [local.site_bucket_arn, "${local.site_bucket_arn}/*"]
  }

  statement {
    sid    = "ProtectStateBucket"
    effect = "Deny"
    actions = [
      "s3:DeleteBucket", "s3:PutBucketPolicy", "s3:DeleteBucketPolicy",
      "s3:PutBucketVersioning", "s3:PutLifecycleConfiguration",
    ]
    resources = [aws_s3_bucket.tfstate.arn]
  }

  statement {
    sid       = "ManageCloudFrontAndCerts"
    actions   = ["cloudfront:*", "acm:*"]
    resources = ["*"]
  }

  # CI cannot create IAM roles. It may only set the permissions policy on the
  # website deploy roles that bootstrap created.
  statement {
    sid       = "ManageDeployRolePermissions"
    actions   = ["iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy"]
    resources = local.deploy_role_arns
  }

  statement {
    sid = "ManageSiteParameters"
    actions = [
      "ssm:PutParameter", "ssm:DeleteParameter",
      "ssm:AddTagsToResource", "ssm:RemoveTagsFromResource",
    ]
    resources = [local.ssm_param_arn]
  }
}

resource "aws_iam_role_policy" "tf_apply" {
  name   = "terraform-apply"
  role   = aws_iam_role.tf_apply.id
  policy = data.aws_iam_policy_document.apply.json
}
