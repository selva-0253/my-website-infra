output "api_base_url" {
  value = "https://${local.api_host}"
}

output "table_name" {
  value = aws_dynamodb_table.engagement.name
}

output "function_name" {
  value = aws_lambda_function.api.function_name
}
