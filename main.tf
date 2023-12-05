data "aws_caller_identity" "this" {}

data "aws_region" "this" {}

locals {
  account_id = data.aws_caller_identity.this.account_id
  region     = data.aws_region.this.name
  is_ws      = var.protocol_type == "WEBSOCKET"
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
    redeployment = sha1(jsonencode([for route_key, route_handler in each.value : [
      aws_apigatewayv2_integration.this[route_key],
      aws_apigatewayv2_route.this[route_key],
      aws_lambda_function.this["${each.key}-${var.routes[route_key]}"],
    ]]))
  }

  lifecycle {
    create_before_destroy = true
  }
}
