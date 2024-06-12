provider "aws" {
  region = "us-east-2"
}

terraform {
	required_providers {
		aws = {
	    version = "~> 5.52.0"
		}
  }
}

# S3 BUCKET
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "crypto-lambda-deployment-bucket"
}

# DYNAMO DB Table
resource "aws_dynamodb_table" "crypto_prices" {
  name         = "CryptoPrices"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"  # Primary key

  attribute {
    name = "id"
    type = "S"  # String type
  }

  tags = {
    Name        = "CryptoPrices"
    Environment = "production"
  }
}

# IAM Policy for s3AdminUser
resource "aws_iam_user_policy" "s3AdminUser_policy" {
  name = "s3AdminUserPolicy"
  user = "s3AdminUser"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "iam:ListRolePolicies",
        Resource = "arn:aws:iam::773094625927:role/lambda_execution_role"
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name = "lambda_policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:BatchWriteItem"
        ],
        Effect   = "Allow",
        Resource = aws_dynamodb_table.crypto_prices.arn
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Define the IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "lambda_role_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# Lambda Function configuration
resource "aws_lambda_function" "api_to_dynamodb" {
  function_name = "api_to_dynamodb"
  architectures = ["arm64"]
  s3_bucket     = aws_s3_bucket.lambda_bucket.bucket
  s3_key        = "python.zip"
  handler       = "lambda_function.lambda_handler"
  layers        = ["arn:aws:lambda:us-east-2:773094625927:layer:myCryptoLayerV2:1"]
  runtime       = "python3.11"
  role          = aws_iam_role.lambda_role.arn

  logging_config {
  log_format = "Text"
  log_group  = "/aws/lambda/api_to_dynamodb"
  }

  memory_size                    = "128"
  package_type                   = "Zip"
  reserved_concurrent_executions = "-1"
  skip_destroy                   = "false"
  timeout                        = "300"

  tracing_config {
    mode = "PassThrough"
  }

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.crypto_prices.name
    }
  }

  ephemeral_storage {
    size = "512"
  }
}

# Lambda Layer configuration
resource "aws_lambda_layer_version" "lambda_layer_version" {
  compatible_architectures = ["arm64"]
  compatible_runtimes      = ["python3.11"]
  layer_name               = "myCryptoLayerV2"
  s3_bucket     = aws_s3_bucket.lambda_bucket.bucket
  s3_key        = "python.zip"
}

# CloudWatch Event Rule to trigger the Lambda function daily
resource "aws_cloudwatch_event_rule" "daily_trigger" {
  name                = "daily_lambda_trigger"
  description         = "Triggers lambda function every day"
  schedule_expression = "cron(0 5 * * ? *)"
}

# CloudWatch Event Target to associate the rule with the Lambda function
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.daily_trigger.name
  target_id = "lambda_function"
  arn       = aws_lambda_function.api_to_dynamodb.arn
}

# Permission to allow CloudWatch Events to invoke the Lambda function
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_to_dynamodb.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_trigger.arn
}
