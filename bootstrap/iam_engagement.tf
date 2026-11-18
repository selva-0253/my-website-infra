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

# API Gateway custom domains (api.<domain>) need this account-wide role, which
# AWS creates on first use. CI cannot create IAM roles, so bootstrap does.
# If it already exists in the account, import it instead of creating:
#   terraform import aws_iam_service_linked_role.apigateway \
#     arn:aws:iam::<account id>:role/aws-service-role/ops.apigateway.amazonaws.com/AWSServiceRoleForAPIGateway
resource "aws_iam_service_linked_role" "apigateway" {
  aws_service_name = "ops.apigateway.amazonaws.com"
}
