# OIDC provider shared by both repos (infra workflow + website deploy role).
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
  repo     = var.infra_repository

  # Everything the site config may create is prefixed with project_name.
  role_prefix_arn   = "arn:aws:iam::${local.account_id}:role/${var.project_name}-*"
  bucket_prefix_arn = "arn:aws:s3:::${var.project_name}-*"
}

# =====================================================================
# PLAN role: read-only. Used by PRs and by the plan job on main.
# =====================================================================

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
      values = [
        "repo:${local.repo}:pull_request",
        "repo:${local.repo}:ref:refs/heads/main",
      ]
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
      "route53:Get*", "route53:List*",
      "iam:Get*", "iam:List*",
    ]
    resources = ["*"]
  }

  # plan takes the state lock, which writes/deletes a .tflock object.
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

# =====================================================================
# APPLY role: write. Only the approval-gated GitHub environment can use it.
# =====================================================================

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
      values   = ["repo:${local.repo}:environment:${var.apply_environment}"]
    }
  }
}

resource "aws_iam_role" "tf_apply" {
  name               = "${var.project_name}-tf-apply"
  assume_role_policy = data.aws_iam_policy_document.apply_trust.json
}

data "aws_iam_policy_document" "apply" {
  # Read anything the plan role can read (refresh step).
  source_policy_documents = [data.aws_iam_policy_document.plan.json]

  statement {
    sid       = "StateReadWrite"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.tfstate.arn}/*"]
  }

  statement {
    sid       = "ManageSiteBuckets"
    actions   = ["s3:*"]
    resources = [local.bucket_prefix_arn, "${local.bucket_prefix_arn}/*"]
  }

  # Never let CI delete or rewrite the state bucket's own config.
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

  statement {
    sid = "ManageSiteRoles"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy", "iam:TagRole", "iam:UntagRole",
      "iam:PutRolePolicy", "iam:DeleteRolePolicy",
    ]
    resources = [local.role_prefix_arn]
  }

  # CI must not be able to modify its own roles.
  statement {
    sid       = "ProtectCiRoles"
    effect    = "Deny"
    actions   = ["iam:*"]
    resources = [aws_iam_role.tf_plan.arn, aws_iam_role.tf_apply.arn]
  }

  dynamic "statement" {
    for_each = var.hosted_zone_id == null ? [] : [var.hosted_zone_id]
    content {
      sid       = "ManageSiteDns"
      actions   = ["route53:ChangeResourceRecordSets"]
      resources = ["arn:aws:route53:::hostedzone/${statement.value}"]
    }
  }
}

resource "aws_iam_role_policy" "tf_apply" {
  name   = "terraform-apply"
  role   = aws_iam_role.tf_apply.id
  policy = data.aws_iam_policy_document.apply.json
}
