data "aws_caller_identity" "this" {}

data "aws_region" "this" {}

locals {
  account_id = data.aws_caller_identity.this.account_id
  region     = data.aws_region.this.name
  is_ws      = var.protocol_type == "WEBSOCKET"
  # Regex that matches all characters in an API route key or S3 key that are
  # invalid when used in a Lambda function name or IAM role name.
  key_regex = "/[\\s/\\$]+/"
  route_keys = toset(flatten([
    for stage_name, route_handlers in var.stages : [
      for route_handler in route_handlers : route_handler.route_key
    ]
  ]))
  route_handlers = flatten([
    for stage_name, route_handlers in var.stages : [
      for route_handler in route_handlers : {
        stage           = stage_name
        route_key       = route_handler.route_key
        s3_key          = route_handler.s3_key
        runtime         = route_handler.runtime
        entrypoint      = route_handler.entrypoint
        policy_arns     = route_handler.policy_arns
        inline_policies = route_handler.inline_policies
      }
    ]
  ])
}

resource "aws_apigatewayv2_api" "this" {
  name                       = var.name
  protocol_type              = var.protocol_type
  route_selection_expression = local.is_ws ? "$request.body.action" : "$request.method $request.path"
}

resource "aws_apigatewayv2_stage" "this" {
  for_each = var.stages

  api_id        = aws_apigatewayv2_api.this.id
  name          = each.key
  deployment_id = aws_apigatewayv2_deployment.this[each.key].id
  default_route_settings {
    logging_level          = local.is_ws ? "INFO" : null
    throttling_burst_limit = 5000
    throttling_rate_limit  = 10000
  }
  stage_variables = {
    stage = each.key
  }
}

resource "aws_apigatewayv2_deployment" "this" {
  for_each = var.stages

  api_id      = aws_apigatewayv2_api.this.id
  description = "${var.protocol_type} ${aws_apigatewayv2_api.this.id} ${each.key} deployment"
  # A new stage deployment needs to be created anytime:
  # - a route key's route or integration changes or
  # - a Lambda function underlying a route key's integration changes.
  triggers = {
    redeployment = sha1(jsonencode([for route_handler in each.value : [
      aws_apigatewayv2_integration.this[route_handler.route_key],
      aws_apigatewayv2_route.this[route_handler.route_key],
      aws_lambda_function.this[route_handler.s3_key],
    ]]))
  }

  lifecycle {
    create_before_destroy = true
  }
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

