locals {
  name_prefix = "${var.project}-${var.environment}"
}

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  lower   = true
  numeric = true
  special = false
}

# ---------------------
# S3 Bucket
# ---------------------
resource "aws_s3_bucket" "primary" {
  bucket = "${replace(local.name_prefix, "_", "-")}-bucket-${random_string.suffix.result}"
}

resource "aws_s3_bucket_public_access_block" "primary" {
  bucket                  = aws_s3_bucket.primary.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "primary" {
  bucket = aws_s3_bucket.primary.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "primary" {
  bucket = aws_s3_bucket.primary.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ---------------------
# DynamoDB Table
# ---------------------
resource "aws_dynamodb_table" "items" {
  name         = "${local.name_prefix}-items"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# ---------------------
# IAM for Lambda
# ---------------------
resource "aws_iam_role" "lambda_exec" {
  name               = "${local.name_prefix}-lambda-exec"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda_access" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject"
    ]
    resources = [
      "${aws_s3_bucket.primary.arn}/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "dynamodb:PutItem"
    ]
    resources = [
      aws_dynamodb_table.items.arn
    ]
  }
}

resource "aws_iam_role_policy" "lambda_access" {
  name   = "${local.name_prefix}-lambda-access"
  role   = aws_iam_role.lambda_exec.id
  policy = data.aws_iam_policy_document.lambda_access.json
}

# ---------------------
# Lambda Function
# ---------------------
data "archive_file" "hello_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/hello"
  output_path = "${path.module}/hello.zip"
}

resource "aws_lambda_function" "hello" {
  function_name = "${local.name_prefix}-hello"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "app.handler"
  runtime       = "python3.12"

  filename         = data.archive_file.hello_zip.output_path
  source_code_hash = data.archive_file.hello_zip.output_base64sha256

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.primary.bucket
      TABLE_NAME  = aws_dynamodb_table.items.name
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_hello
  ]
}

# Pre-create the log group with retention (optional but useful)
resource "aws_cloudwatch_log_group" "lambda_hello" {
  name              = "/aws/lambda/${local.name_prefix}-hello"
  retention_in_days = 14
}

# ---------------------
# CloudWatch Alarm on Lambda Errors
# ---------------------
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${local.name_prefix}-hello-errors"
  alarm_description   = "Alarm when Lambda reports any errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0

  dimensions = {
    FunctionName = aws_lambda_function.hello.function_name
  }
}