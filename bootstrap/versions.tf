terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Run this once with local state (from your VM/laptop, admin credentials).
  # Optionally move its state into the bucket it creates afterwards:
  #   uncomment, set bucket, then `terraform init -migrate-state`.
  #
  # backend "s3" {
  #   bucket       = "<tf_state_bucket output>"
  #   key          = "my-website/bootstrap.tfstate"
  #   region       = "ap-south-1"
  #   encrypt      = true
  #   use_lockfile = true
  # }
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
