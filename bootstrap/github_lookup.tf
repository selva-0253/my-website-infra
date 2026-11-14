# IDs are read from GitHub, never typed in.

data "github_user" "owner" {
  username = var.github_owner
}

data "github_repository" "infra" {
  full_name = "${var.github_owner}/${var.infra_repository}"
}

data "github_repository" "website" {
  full_name = "${var.github_owner}/${var.website_repository}"
}

locals {
  # GitHub OIDC `sub` claim prefixes. Current repos send the ID-qualified form
  # (repo:owner@<owner_id>/name@<repo_id>:...); the legacy name-only form is
  # also accepted so a format change on GitHub's side can't lock CI out.
  # The IDs make the trust survive a repo being deleted and its name reused.
  infra_sub_prefixes = [
    "repo:${var.github_owner}@${data.github_user.owner.id}/${var.infra_repository}@${data.github_repository.infra.repo_id}",
    "repo:${var.github_owner}/${var.infra_repository}",
  ]
  website_sub_prefixes = [
    "repo:${var.github_owner}@${data.github_user.owner.id}/${var.website_repository}@${data.github_repository.website.repo_id}",
    "repo:${var.github_owner}/${var.website_repository}",
  ]
}
