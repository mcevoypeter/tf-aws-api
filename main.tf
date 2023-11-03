terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_iam_policy_document" "allow_cloudwatch_access_from_apigw" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "logger" {
  name                = "APIGatewayLogger"
  assume_role_policy  = data.aws_iam_policy_document.allow_cloudwatch_access_from_apigw.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"]
}

# Enable API Gateway to write logs to CloudWatch.
resource "aws_api_gateway_account" "this" {
  cloudwatch_role_arn = aws_iam_role.logger.arn
}

resource "aws_apigatewayv2_api" "this" {
  name          = var.name
  protocol_type = var.protocol_type
}

resource "aws_apigatewayv2_stage" "this" {
  for_each = var.stages

  api_id      = aws_apigatewayv2_api.this.id
  name        = each.value
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw_trigger" {
  for_each = {
    for idx, route in var.routes : route.key => route
  }

  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = each.value.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*"
}

resource "aws_apigatewayv2_integration" "this" {
  for_each = {
    for idx, route in var.routes : route.key => route
  }

  api_id = aws_apigatewayv2_api.this.id
  # see https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-api-integration-types.html
  integration_type = "AWS_PROXY"
  connection_type  = "INTERNET"
  integration_uri  = each.value.invoke_arn
}

resource "aws_apigatewayv2_route" "this" {
  for_each = {
    for idx, route in var.routes : route.key => route
  }

  api_id    = aws_apigatewayv2_api.this.id
  route_key = each.key
  target    = "integrations/${aws_apigatewayv2_integration.this[each.key].id}"
}
