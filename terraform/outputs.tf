output "s3_bucket_name" {
  description = "Primary S3 bucket name"
  value       = aws_s3_bucket.primary.bucket
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.items.name
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.hello.function_name
}