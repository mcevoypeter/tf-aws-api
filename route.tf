locals {
  route_handlers = flatten([
    for stage_name, route_handlers in var.stages : [
      for route_key, route_handler in route_handlers : {
        function_name   = "${stage_name}-${var.routes[route_key]["name_suffix"]}"
        route_key       = route_key
        s3_key          = route_handler.s3_key
        runtime         = route_handler.runtime
        entrypoint      = route_handler.entrypoint
        policy_arns     = route_handler.policy_arns
        inline_policies = route_handler.inline_policies
      }
    ]
  ])
}

resource "aws_iam_role" "this" {
  for_each = {
    for route_handler in local.route_handlers : route_handler.function_name => route_handler
  }

  name               = "Lambda-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  managed_policy_arns = concat([
    # permissions required to invoke the function
    "arn:aws:iam::aws:policy/service-role/AWSLambdaRole",
    # permissions required to write logs to CloudWatch
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
  ], each.value.policy_arns)
  # This `ExecuteAPIFullAccess` inline policy is necessary for WebSocket APIs
  # that use `@connections` callbacks (see
  # https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-how-to-call-websocket-api-connections.html)
  # to send responses to conncted clients.
  dynamic "inline_policy" {
    for_each = local.is_ws ? [null] : []
    content {
      name = "ExecuteAPIFullAccess"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "execute-api:Invoke",
              "execute-api:ManageConnections",
              "execute-api:InvalidateCache",
            ],
            Resource = "${aws_apigatewayv2_api.this.execution_arn}/*"
          }
        ]
      })
    }
  }
  dynamic "inline_policy" {
    for_each = each.value.inline_policies
    content {
      name   = inline_policy.value["name"]
      policy = inline_policy.value["policy"]
    }
  }
}

data "aws_s3_object" "this" {
  for_each = {
    for route_handler in local.route_handlers : route_handler.function_name => route_handler
  }

  bucket        = var.handlers_s3_bucket
  key           = each.value.s3_key
  checksum_mode = "ENABLED"
}

resource "aws_lambda_function" "this" {
  for_each = {
    for route_handler in local.route_handlers : route_handler.function_name => route_handler
  }

  s3_bucket        = var.handlers_s3_bucket
  s3_key           = each.value.s3_key
  function_name    = each.key
  runtime          = each.value.runtime
  handler          = each.value.entrypoint
  source_code_hash = data.aws_s3_object.this[each.key].checksum_sha256
  role             = aws_iam_role.this[each.key].arn
}

resource "aws_lambda_permission" "apigw_trigger" {
  for_each = {
    for route_handler in local.route_handlers : route_handler.function_name => route_handler
  }

  statement_id  = "AllowExecutionFromAPIGateway-${var.name}"
  action        = "lambda:InvokeFunction"
  function_name = each.key
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*"

  depends_on = [aws_lambda_function.this]
}

resource "aws_apigatewayv2_integration" "this" {
  for_each = var.routes

  api_id = aws_apigatewayv2_api.this.id
  # see https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-api-integration-types.html
  integration_type = "AWS_PROXY"
  connection_type  = "INTERNET"
  # see https://stackoverflow.com/a/68912233
  integration_uri        = "arn:aws:lambda:${local.region}:${local.account_id}:function:$${stageVariables.stage}-${each.value["name_suffix"]}"
  payload_format_version = local.is_ws ? "1.0" : "2.0"
}

resource "aws_apigatewayv2_route" "this" {
  for_each = var.routes

  api_id    = aws_apigatewayv2_api.this.id
  route_key = each.key
  target    = "integrations/${aws_apigatewayv2_integration.this[each.key].id}"
  # Lambda authorizers can only be used on HTTP routes or the WebSocket $connect route.
  authorization_type = var.authorizer == null || (local.is_ws && each.key != "$connect") ? "NONE" : "CUSTOM"
  authorizer_id      = var.authorizer == null || (local.is_ws && each.key != "$connect") ? null : aws_apigatewayv2_authorizer.this[0].id
}
