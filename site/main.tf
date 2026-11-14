data "aws_caller_identity" "current" {}

locals {
  name   = "${var.project_name}-${var.environment}"
  bucket = coalesce(var.bucket_name, "${local.name}-site-${data.aws_caller_identity.current.account_id}")

  use_domain = var.domain_name != null
  aliases = local.use_domain ? concat(
    [var.domain_name],
    var.include_www ? ["www.${var.domain_name}"] : []
  ) : []

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
