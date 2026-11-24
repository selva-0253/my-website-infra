data "aws_iam_role" "lambda" {
  name = var.lambda_role_name
}

locals {
  function_name = "${var.name}-engagement-api"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_days
}

# What the function may do. The role itself comes from bootstrap.
data "aws_iam_policy_document" "lambda" {
  statement {
    sid = "EngagementTable"
    actions = [
      "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
      "dynamodb:Query", "dynamodb:ConditionCheckItem",
    ]
    resources = [aws_dynamodb_table.engagement.arn]
  }

  # Only the CV object itself, only to sign short-lived download links.
  dynamic "statement" {
    for_each = var.private_assets_bucket == null ? [] : [1]
    content {
      sid       = "ReadCv"
      actions   = ["s3:GetObject"]
      resources = ["arn:aws:s3:::${var.private_assets_bucket}/private/cv.pdf"]
    }
  }

  statement {
    sid       = "Logs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.lambda.arn}:*"]
  }
}

resource "aws_iam_role_policy" "lambda" {
  name   = "engagement-api"
  role   = data.aws_iam_role.lambda.name
  policy = data.aws_iam_policy_document.lambda.json
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/src/handler.py"
  # Under the environment folder so CI ships it from plan to apply.
  output_path = "${path.root}/.build/${var.name}-engagement-api.zip"
}

resource "aws_lambda_function" "api" {
  function_name    = local.function_name
  role             = data.aws_iam_role.lambda.arn
  runtime          = "python3.13"
  architectures    = ["arm64"]
  handler          = "handler.handler"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  memory_size      = 128
  timeout          = 10

  environment {
    variables = {
      TABLE_NAME                = aws_dynamodb_table.engagement.name
      ORIGIN_SECRET             = random_password.origin_secret.result
      TURNSTILE_SECRET          = var.turnstile_secret_key
      ALLOWED_HOSTNAMES         = join(",", local.site_hosts)
      COMMENTS_REQUIRE_APPROVAL = tostring(var.comments_require_approval)
      CV_BUCKET                 = coalesce(var.private_assets_bucket, "-")
      CV_KEY                    = "private/cv.pdf"
      CV_DOWNLOAD_NAME          = var.cv_download_name
      CV_LINK_TTL               = tostring(var.cv_link_ttl_seconds)
    }
  }

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.lambda.name
  }

  depends_on = [aws_iam_role_policy.lambda]
}
