# Passed with:  terraform init -backend-config=backend.hcl \
#                 -backend-config="bucket=$TF_STATE_BUCKET" -backend-config="region=$AWS_REGION"
key          = "envs/prod/terraform.tfstate"
encrypt      = true
use_lockfile = true
