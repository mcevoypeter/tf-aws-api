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
  # If the user supplies a custom domain, it'll be usable as an endpoint so
  # there's no need for the execute-api endpoint.
  disable_execute_api_endpoint = var.domain != null
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

