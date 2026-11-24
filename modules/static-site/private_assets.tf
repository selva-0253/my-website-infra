# Private files for the site owner's profile (photo, CV). Never served directly.
#
#   public/photo.<ext>  copied into the site at deploy time (shown on the About page)
#   private/cv.pdf      never copied; the engagement API hands out short-lived
#                       download links after a bot check
#
# Upload with: aws s3 cp <file> s3://<bucket>/<key>   (see docs/07)

resource "aws_s3_bucket" "private_assets" {
  bucket = "${var.name}-private-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_ownership_controls" "private_assets" {
  bucket = aws_s3_bucket.private_assets.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "private_assets" {
  bucket                  = aws_s3_bucket.private_assets.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "private_assets" {
  bucket = aws_s3_bucket.private_assets.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Replacing your CV keeps the previous versions for 90 days.
resource "aws_s3_bucket_versioning" "private_assets" {
  bucket = aws_s3_bucket.private_assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "private_assets" {
  bucket = aws_s3_bucket.private_assets.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.private_assets]
}

data "aws_iam_policy_document" "private_assets" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.private_assets.arn, "${aws_s3_bucket.private_assets.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "private_assets" {
  bucket = aws_s3_bucket.private_assets.id
  policy = data.aws_iam_policy_document.private_assets.json

  depends_on = [aws_s3_bucket_public_access_block.private_assets]
}

resource "aws_ssm_parameter" "private_assets_bucket" {
  name  = "${var.parameter_prefix}/private_assets_bucket"
  type  = "String"
  value = aws_s3_bucket.private_assets.id
}
