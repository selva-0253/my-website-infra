# Add these as GitHub *variables* in the infra repo
# (Settings > Secrets and variables > Actions > Variables).

output "TF_STATE_BUCKET" {
  value = aws_s3_bucket.tfstate.id
}

output "TF_PLAN_ROLE_ARN" {
  value = aws_iam_role.tf_plan.arn
}

output "TF_APPLY_ROLE_ARN" {
  value = aws_iam_role.tf_apply.arn
}

output "AWS_REGION" {
  value = var.aws_region
}
