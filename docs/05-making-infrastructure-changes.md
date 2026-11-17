# Making Infrastructure Changes

How to change the tecssol.uk infrastructure safely: where each kind of change goes, the step-by-step process, and what to avoid.

---

## 1. The rule

All infrastructure changes are made **in the existing `my-website-infra` repository**, by modifying or adding files. You never start a new Terraform project, and you never change resources by hand in the AWS, Cloudflare or GitHub consoles.

---

## 2. When the pipeline runs

The Terraform pipeline starts only when one of these paths changes:

| Path | Triggers the pipeline? |
|---|---|
| `envs/**` | Yes |
| `modules/**` | Yes |
| `.github/workflows/terraform*.yml` | Yes |
| `docs/**`, `README.md` | No: documentation doesn't change infrastructure |
| `bootstrap/**` | No: bootstrap is run by an administrator from the admin VM |

To run the pipeline without changing code, use GitHub → **Actions** → **Terraform** → **Run workflow** (branch `main`).

---

## 3. Where each kind of change goes

| Kind of change | Example | Where | Applied by |
|---|---|---|---|
| **A setting** | Different domain, drop `www`, change CloudFront price class | `envs/prod/terraform.tfvars` | Pipeline |
| **Something every site should have** | Access logs, a WAF, a custom 404 page, a cache rule | Add or edit `.tf` files in `modules/static-site/` (plus a variable if it should be optional) | Pipeline |
| **Something only prod needs** | A prod-only alarm, an extra DNS record for email | A new `.tf` file in `envs/prod/` | Pipeline |
| **A new environment** | `dev` | Bootstrap settings, a new `envs/dev` folder, a pipeline job, a secret, and a website deploy workflow (full walkthrough in section 6) | Bootstrap on the admin VM first, then the pipeline |
| **Permissions or GitHub settings** | Let CI manage a new AWS service; change approvers | `bootstrap/` | An administrator on the admin VM |

---

## 4. Step by step (changes applied by the pipeline)

1. **Create a branch.**
   ```bash
   git checkout main && git pull
   git checkout -b <short-description>      # e.g. add-access-logs
   ```
2. **Edit** the files identified in section 3.
3. **Format** (optional locally; the pipeline fails on unformatted files):
   ```bash
   terraform fmt -recursive
   ```
4. **Push the branch and open a pull request.** The pipeline runs **plan** with the read-only role.
5. **Review the plan.** Open the pipeline run → **Summary**:
   - check the *add / change / destroy* counts;
   - make sure nothing important is **destroyed or replaced** unexpectedly. "Must be replaced" means delete and recreate.
6. **Merge** the pull request to `main`. The pipeline plans again and saves that exact plan.
7. **Approve** the `infra-prod` deployment (run page → *Review deployments* → *Approve and deploy*). The saved plan is applied.
8. **Check** the run's **Outputs** summary, and the site itself.

---

## 5. Adding a new AWS service: update permissions first

The CI roles may use only the AWS services the site uses today: S3, CloudFront, ACM, Systems Manager Parameter Store, and the deploy role's permissions. That keeps them least-privilege.

If a change introduces a **new AWS service**, such as AWS WAF, CloudWatch alarms or Lambda:

1. On the admin VM, add the required actions to `bootstrap/iam_ci.tf`:
   - **read** actions (`Describe*`, `Get*`, `List*`) in the **plan** policy;
   - **write** actions in the **apply** policy, limited to project-prefixed resources where the service allows it.
2. Apply bootstrap:
   ```bash
   cd ~/my-website-infra && git pull
   cd bootstrap
   export GITHUB_TOKEN=<token>
   terraform plan      # should show only the policy changes
   terraform apply
   ```
3. Commit and push the bootstrap change.
4. Then open the pull request with the new resources (section 4).

If this is skipped, the pipeline fails with **AccessDenied**. The error message names the missing action to add.

---

## 6. Adding a new environment (example: `dev`)

A new environment is a full, isolated copy of the platform: its own bucket, CloudFront distribution, certificate, DNS records, Terraform state, approval gate, deploy role and website branch. It's mostly configuration, plus two small code additions (marked **A** and **B**).

### 6.1 Decide first

| Decision | Example for `dev` |
|---|---|
| Environment name | `dev` |
| Domain | `dev.tecssol.uk` (a subdomain in the existing Cloudflare zone), or none to use the CloudFront URL |
| Website GitHub environment | `development` |
| Website branch that publishes to it | `develop` (prod stays on `main`) |
| Approval before apply | Same as prod, or none |

### 6.2 Step 1: Bootstrap (admin VM)

Edit `bootstrap/terraform.tfvars`:
```hcl
environments = {
  prod = {
    website_github_environment = "production"
  }
  dev = {
    website_github_environment = "development"
    website_branch             = "develop"
  }
}
```
Apply:
```bash
cd ~/my-website-infra && git pull && cd bootstrap
export GITHUB_TOKEN=<token>
terraform plan     # expect: additions for dev + updates to the two CI role policies
terraform apply
```
Commit and push `bootstrap/terraform.tfvars`.

This creates:
- the `infra-dev` approval environment in the infra repository;
- the `my-website-dev-site-deploy` role;
- the website repository's `development` environment, with its three variables and a rule allowing only the `develop` branch.

It also lets the apply role sign in from `infra-dev` and manage the dev deploy role. **Prod is not changed.**

### 6.3 Step 2: Create the environment folder

```bash
cp -r envs/prod envs/dev
```
`envs/dev/terraform.tfvars`:
```hcl
project_name = "my-website"
environment  = "dev"
aws_region   = "ap-south-1"

domain_name          = "dev.tecssol.uk"
include_www          = false            # avoid www.dev.tecssol.uk
cloudflare_zone_name = "tecssol.uk"     # see code addition A
```
`envs/dev/backend.hcl`:
```hcl
key = "envs/dev/terraform.tfstate"
```
Keep the copied `.terraform.lock.hcl`.

**Code addition A: pass the Cloudflare zone name (needed for subdomains).**
The module finds the Cloudflare zone using the domain name, but `dev.tecssol.uk` is not a zone; `tecssol.uk` is. The module already accepts `cloudflare_zone_name`, but the environment folder doesn't pass it yet. Add this to `envs/dev` (and to `envs/prod`, so both folders stay identical):
- `variables.tf`:
  ```hcl
  variable "cloudflare_zone_name" {
    type    = string
    default = null
  }
  ```
- `main.tf`, inside `module "site" { … }`:
  ```hcl
  cloudflare_zone_name = var.cloudflare_zone_name
  ```

### 6.4 Step 3: Add the pipeline job

In `.github/workflows/terraform.yml`, under `jobs:`:
```yaml
  dev:
    uses: ./.github/workflows/terraform-env.yml
    with:
      environment: dev
    secrets: inherit
```

### 6.5 Step 4: Add the Cloudflare secret

In `my-website-infra` → Settings → Environments → **infra-dev**, add the environment secret `CLOUDFLARE_API_TOKEN` = the **apply** (DNS edit) token. The read token is already a repository secret, shared by all environments.

### 6.6 Step 5: Apply through the pipeline

```bash
git checkout -b add-dev-environment
git add envs/dev .github/workflows/terraform.yml   # plus envs/prod if addition A was made there
git commit -m "Add dev environment"
git push -u origin add-dev-environment
```
Open a pull request and check both plans:
- **dev**: additions only (about 17 resources; no `www`, so one validation record and one address record);
- **prod**: **no changes**.

Merge, then approve **infra-dev**. `dev.tecssol.uk` then exists.

### 6.7 Step 6: Website deployment to the new environment

**Code addition B: a deploy workflow for the new branch.**
The website's `deploy.yml` is tied to `main` → `production`. In the **my-website** repository, add `.github/workflows/deploy-dev.yml` as a copy of `deploy.yml` with three changes:
```yaml
on:
  push:
    branches: [develop]        # was main
...
concurrency:
  group: deploy-development    # was deploy-production
...
    environment: development   # was production
```
Nothing else changes. The `development` environment's variables, written by bootstrap, point the workflow at the dev role, bucket and CloudFront distribution.

Create the branch:
```bash
git checkout -b develop
git push -u origin develop
```
From then on: push to `develop` → dev.tecssol.uk; push to `main` → tecssol.uk.

### 6.8 Result

| | prod | dev |
|---|---|---|
| URL | tecssol.uk, www.tecssol.uk | dev.tecssol.uk |
| Terraform state | `envs/prod/terraform.tfstate` | `envs/dev/terraform.tfstate` |
| Approval environment | `infra-prod` | `infra-dev` |
| Website branch → GitHub environment | `main` → `production` | `develop` → `development` |
| Deploy role | `my-website-prod-site-deploy` | `my-website-dev-site-deploy` |
| SSM parameters | `/my-website/prod/…` | `/my-website/dev/…` |

A mistake in dev can't change prod: separate state, separate approval, separate deploy role.

### 6.9 Limitation and next step

Both environments live in the **same AWS account** and share the `tf-plan` / `tf-apply` roles. For stronger isolation, the usual enterprise practice is one AWS account per environment. That needs bootstrap to run once per account, with the pipeline choosing roles per environment. It's a larger change, worth making when the project needs that level of separation.

---

## 7. Do not

| Don't | Why | Instead |
|---|---|---|
| Change resources in the AWS / Cloudflare / GitHub consoles | Terraform undoes the change on its next apply, or the plan shows surprise changes (drift) | Make every change in code |
| Push infrastructure changes directly to `main` | Skips the pull-request plan review | Branch → PR → review → merge |
| Rename resources or move them between files/modules without care | Terraform treats a renamed resource as "delete old, create new" | Use a `moved` block so Terraform keeps the existing resource |
| Edit `.terraform.lock.hcl` by hand | It pins provider versions and checksums | Run `terraform init -upgrade` and commit the result |
| Put secret values in `.tf` or `.tfvars` files | They'd be committed and stored in state | Use GitHub secrets / environment variables |

---

## 8. Quick reference

| I want to… | Do this |
|---|---|
| Change a setting | Edit `envs/prod/terraform.tfvars` → PR → merge → approve |
| Add a feature to the site's infrastructure | Edit `modules/static-site/` → PR → merge → approve |
| Use a new AWS service | Update `bootstrap/iam_ci.tf` and apply bootstrap on the VM, then PR |
| Re-run the pipeline | Actions → Terraform → Run workflow |
| Change who approves | `bootstrap/` → apply on the VM |
| Publish website content | Push to `my-website` (not this repository) |
