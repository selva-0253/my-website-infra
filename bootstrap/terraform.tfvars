aws_region   = "ap-south-1"
project_name = "my-website"

github_owner       = "selva-0253"
infra_repository   = "my-website-infra"
website_repository = "my-website"

environments = {
  prod = {
    website_github_environment = "production"
  }
}

# Required reviewers on private repos need GitHub Pro/Team.
# If apply fails with "422 ... reviewers", set this to false.
require_apply_approval = true
