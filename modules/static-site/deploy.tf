# What the website repo's deploy role may do, plus where it finds its targets.

data "aws_iam_role" "deploy" {
  name = var.deploy_role_name
}

resource "aws_ssm_parameter" "site_bucket" {
  name  = "${var.parameter_prefix}/site_bucket"
  type  = "String"
  value = aws_s3_bucket.site.id
}

resource "aws_ssm_parameter" "distribution_id" {
  name  = "${var.parameter_prefix}/cloudfront_distribution_id"
  type  = "String"
  value = aws_cloudfront_distribution.site.id
}

data "aws_iam_policy_document" "deploy" {
  statement {
    sid       = "ReadSiteParameters"
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = [aws_ssm_parameter.site_bucket.arn, aws_ssm_parameter.distribution_id.arn, aws_ssm_parameter.private_assets_bucket.arn]
  }

  # Owner profile (name, links, certifications), set by hand under <prefix>/profile/.
  # String or SecureString (AWS managed key) both work.
  statement {
    sid     = "ReadProfileParameters"
    actions = ["ssm:GetParametersByPath", "ssm:GetParameter", "ssm:GetParameters"]
    resources = [
      "arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:parameter${var.parameter_prefix}/profile",
      "arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:parameter${var.parameter_prefix}/profile/*",
    ]
  }

  # The photo is copied into the site. The CV is never readable by the deploy
  # role; it may only check that private/cv.pdf exists (listing, not reading).
  statement {
    sid       = "ListProfileFiles"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.private_assets.arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["public/*", "private/cv.pdf"]
    }
  }

  statement {
    sid       = "ReadPublicProfileFiles"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.private_assets.arn}/public/*"]
  }

  statement {
    sid       = "ListBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.site.arn]
  }

  statement {
    sid       = "WriteObjects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]
  }

  statement {
    sid       = "InvalidateCache"
    actions   = ["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation"]
    resources = [aws_cloudfront_distribution.site.arn]
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "site-deploy"
  role   = data.aws_iam_role.deploy.name
  policy = data.aws_iam_policy_document.deploy.json
}
