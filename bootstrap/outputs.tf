output "state_bucket" {
  value = aws_s3_bucket.tfstate.id
}

output "tf_plan_role_arn" {
  value = aws_iam_role.tf_plan.arn
}

output "tf_apply_role_arn" {
  value = aws_iam_role.tf_apply.arn
}

output "site_deploy_role_arns" {
  value = { for env, r in aws_iam_role.site_deploy : env => r.arn }
}

output "github_oidc_subjects" {
  description = "Subjects the roles trust (useful when debugging AssumeRoleWithWebIdentity errors)."
  value = {
    infra   = local.infra_sub_prefixes
    website = local.website_sub_prefixes
  }
}
