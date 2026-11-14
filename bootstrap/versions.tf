terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }

  # Bootstrap starts with local state because the state bucket does not exist
  # yet. After the first apply you can move it into that bucket:
  #   terraform init -migrate-state \
  #     -backend-config="bucket=<state_bucket output>" -backend-config="region=<aws_region>" \
  #     -backend-config="key=bootstrap/terraform.tfstate"
  # after replacing this comment block with:  backend "s3" { use_lockfile = true }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform-bootstrap"
    }
  }
}

# Authenticates with the GITHUB_TOKEN environment variable.
provider "github" {
  owner = var.github_owner
}
