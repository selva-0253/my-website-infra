# my-website-infra

Terraform for the static site in [`selva-0253/my-website`](https://github.com/selva-0253/my-website):
private S3 bucket, CloudFront (OAC), optional ACM + Route 53 domain, and the
OIDC role the website repo uses to deploy content.

```
bootstrap/   run once by hand: state bucket, GitHub OIDC provider, CI roles
site/        the website infrastructure, run by GitHub Actions
.github/workflows/terraform.yml   plan on PR, plan + approved apply on main
```

| Role | Who can assume it | Can do |
|---|---|---|
| `my-website-tf-plan` | this repo: PRs and `main` | read-only + state lock |
| `my-website-tf-apply` | this repo: `infra-prod` environment only | manage site buckets, CloudFront, ACM, `my-website-*` roles, site DNS zone |
| `my-website-prod-github-deploy` | website repo: `production` environment | sync site bucket, invalidate CloudFront |

## First-time setup

1. **Bootstrap** (from a machine with admin AWS credentials, Terraform >= 1.10):
   ```bash
   cd bootstrap
   terraform init
   terraform apply          # set -var hosted_zone_id=... if you use a domain
   terraform output
   ```
   If the account already has a GitHub OIDC provider, add
   `-var create_github_oidc_provider=false`.

2. **GitHub, this repo**:
   - Settings → Secrets and variables → Actions → **Variables**: add
     `TF_STATE_BUCKET`, `TF_PLAN_ROLE_ARN`, `TF_APPLY_ROLE_ARN`, `AWS_REGION`
     from the bootstrap outputs.
   - Settings → Environments → create **`infra-prod`**, add yourself as a
     *Required reviewer*, restrict deployment branches to `main`.

3. **Lock file**: run `terraform init -backend-config="bucket=<TF_STATE_BUCKET>"`
   once in `site/` and commit `site/.terraform.lock.hcl`.

4. Push to `main` → the workflow plans, waits for your approval, applies.

5. **GitHub, website repo** → Settings → Environments → `production` → secrets:
   `AWS_ROLE_ARN`, `S3_BUCKET_WEBSITE`, `CLOUDFRONT_DISTRIBUTION_ID`, `AWS_REGION`
   (shown in the apply job summary / `terraform output`). Then delete the old
   `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` secrets.

## Day to day

Change `site/*.tf` or `site/terraform.tfvars` in a PR → review the plan in the
job summary → merge → approve the `infra-prod` deployment.

## Notes

- `bootstrap/` is not run by CI on purpose: CI must not manage the roles it
  runs as. Re-run it by hand if you change CI permissions.
- The apply role can create IAM roles with inline policies under the
  `my-website-*` prefix. That is needed for the website deploy role, but it
  means apply is effectively privileged; the `infra-prod` approval gate is
  what keeps it safe. Keep this repo private and reviewers limited.
- If you set a custom `bucket_name` in `site/`, it must start with
  `my-website-` or the apply role can't manage it.
