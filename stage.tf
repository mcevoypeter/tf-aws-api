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

resource "aws_apigatewayv2_api_mapping" "this" {
  for_each = var.domain != null ? var.stages : {}

  api_id      = aws_apigatewayv2_api.this.id
  domain_name = aws_apigatewayv2_domain_name.this[0].id
  stage       = aws_apigatewayv2_stage.this[each.key].id
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
      aws_lambda_function.route_handler[route_handler.s3_key],
    ]]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

