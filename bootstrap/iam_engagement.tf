# Execution role for the engagement API Lambda, one per environment.
# Bootstrap owns the role (CI cannot create IAM roles); envs/<env> attaches
# its permissions (the table and log group only exist there).

data "aws_iam_policy_document" "engagement_lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_iam_role" "engagement_lambda" {
  for_each = var.environments

  name               = "${var.project_name}-${each.key}-engagement-api"
  assume_role_policy = data.aws_iam_policy_document.engagement_lambda_trust.json
}
