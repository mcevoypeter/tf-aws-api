resource "aws_apigatewayv2_api" "this" {
  name                       = var.name
  protocol_type              = var.protocol_type
  route_selection_expression = var.protocol_type == "WEBSOCKET" ? "$request.body.action" : "$request.method $request.path"
}

resource "aws_apigatewayv2_stage" "this" {
  for_each = var.stages

  api_id      = aws_apigatewayv2_api.this.id
  name        = each.value
  auto_deploy = true
  default_route_settings {
    logging_level          = "INFO"
    throttling_burst_limit = 5000
    throttling_rate_limit  = 10000
  }
  dynamic "route_settings" {
    for_each = {
      for idx, route in var.routes : route.key => route
    }
    content {
      route_key              = route_settings.key
      logging_level          = "INFO"
      throttling_burst_limit = 5000
      throttling_rate_limit  = 10000
    }
  }
}
