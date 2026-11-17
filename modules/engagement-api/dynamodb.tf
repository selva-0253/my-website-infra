# One table, keyed by post:
#   pk = POST#<slug>  sk = STATS                 likes counter
#   pk = POST#<slug>  sk = LIKE#<visitor hash>    one per visitor (no IPs stored)
#   pk = POST#<slug>  sk = COMMENT#<time>#<id>    a comment
resource "aws_dynamodb_table" "engagement" {
  name         = "${var.name}-engagement"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"
  range_key    = "sk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  deletion_protection_enabled = true
}
