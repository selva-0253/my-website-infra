data "aws_caller_identity" "current" {}

locals {
  bucket = coalesce(var.bucket_name, "${var.name}-site-${data.aws_caller_identity.current.account_id}")

  use_domain = var.domain_name != null
  zone_name  = coalesce(var.cloudflare_zone_name, var.domain_name, "unused")
  aliases = local.use_domain ? concat(
    [var.domain_name],
    var.include_www ? ["www.${var.domain_name}"] : []
  ) : []
}
