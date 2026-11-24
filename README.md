# my-website-infra

Terraform for the static site in `selva-0253/my-website`: private S3 bucket,
CloudFront (OAC), ACM certificate, Cloudflare DNS, and the OIDC role the
website repo deploys with.

```
bootstrap/                  once per AWS account, run by an admin (local)
  terraform.tfvars          account / repo / environment settings
modules/static-site/        reusable site module (no environment values)
envs/prod/                  one folder per environment
  terraform.tfvars          environment settings (domain, region)
  backend.hcl               state key for this environment
.github/workflows/
  terraform.yml             triggers; one job per environment
  terraform-env.yml         reusable plan -> approval -> apply
```

## Who manages what

| Item | Managed by |
|---|---|
| State bucket, GitHub OIDC provider | bootstrap |
| `my-website-tf-plan` / `-tf-apply` roles (infra CI) | bootstrap |
| `my-website-<env>-site-deploy` role trust (who can deploy) | bootstrap |
| GitHub environments `infra-<env>` and website `production` | bootstrap |
| GitHub variables (infra repo + website `production` env) | bootstrap |
| Bucket, CloudFront, certificate, DNS, deploy role permissions, SSM parameters | `envs/<env>` via CI |
| Cloudflare API tokens (GitHub secrets) | you, by hand (credentials) |

GitHub account and repository IDs used in the OIDC trust policies are looked
up from the GitHub API. Nothing account-specific is in module code.

## One-time setup

Prerequisites on the admin machine: Terraform >= 1.10, AWS CLI v2, admin AWS
login (`aws configure sso`).

1. **Tokens**
   - GitHub fine-grained token, repos `my-website` and `my-website-infra`,
     permissions: Administration RW, Environments RW, Variables RW, Metadata R.
   - Cloudflare API tokens for zone `tecssol.uk`:
     - plan: *Zone:Read* + *DNS:Read*
     - apply: *Zone:Read* + *DNS:Edit*
2. **Bootstrap**
   ```bash
   export GITHUB_TOKEN=<github token>
   cd bootstrap
   terraform init -upgrade
   terraform plan
   terraform apply
   ```
3. **Secrets** in `my-website-infra`:
   - Settings > Secrets and variables > Actions > *Repository secret*
     `CLOUDFLARE_API_TOKEN` = plan token
   - Settings > Environments > `infra-prod` > *Environment secret*
     `CLOUDFLARE_API_TOKEN` = apply token
4. Push. The workflow plans, waits for approval on `infra-prod`, applies.
   (`.terraform.lock.hcl` files are committed with hashes for all platforms.
   After changing provider versions run `terraform init -upgrade` and commit them.)
5. Push the website repo (or run its workflow) to publish content.

## Day to day

- **Infrastructure change**: PR -> review plan in the job summary -> merge ->
  approve `infra-prod`.
- **Content change**: push to `my-website` `main`.
- **Profile details, photo, CV**: Parameter Store + private bucket, see
  [docs/07](docs/07-profile-and-private-files.md); then re-run the website deploy.
- **New environment** (e.g. `dev`): copy `envs/prod` to `envs/dev`, change its
  `terraform.tfvars` and `backend.hcl` key, add `dev` to bootstrap
  `environments`, re-apply bootstrap, add a `dev` job to `terraform.yml`.

## Notes

- Bootstrap is never run by CI: CI must not manage the roles it runs as.
- The apply role cannot create IAM roles; it may only set the permissions
  policy on the deploy roles bootstrap created.
- `envs/<env>` relies on bootstrap's naming: deploy role
  `<project>-<env>-site-deploy`, parameters under `/<project>/<env>/`.
- Cloudflare records are DNS-only (grey cloud). Remove any existing apex/`www`
  records for the domain before the first apply.
