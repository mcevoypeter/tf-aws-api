resource "aws_iam_role" "route_handler" {
  for_each = {
    for route_handler in local.route_handlers : route_handler.s3_key => route_handler
  }

  name               = "Lambda-${replace(each.key, local.key_regex, "-")}"
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
    for route_handler in local.route_handlers : route_handler.s3_key => route_handler
  }

  bucket        = var.handlers_s3_bucket
  key           = each.key
  checksum_mode = "ENABLED"
}

resource "aws_lambda_function" "route_handler" {
  for_each = {
    for route_handler in local.route_handlers : route_handler.s3_key => route_handler
  }

  s3_bucket = var.handlers_s3_bucket
  s3_key    = each.key
  # A route handler's Lambda function name is of the form
  # `<api_id>-<api_type>-<api_stage>-<route_key>`. Note that all whitespace in
  # the route key is replaced with underscores.
  function_name = format(
    "%s-%s-%s-%s",
    local.is_ws ? "ws" : "http",
    aws_apigatewayv2_api.this.id,
    each.value.stage,
    # This needs to match the replace() call in the aws_apigatewayv2_integration.this resource.
    replace(each.value.route_key, local.key_regex, "-"),
  )
  runtime          = each.value.runtime
  handler          = each.value.entrypoint
  source_code_hash = data.aws_s3_object.this[each.value.s3_key].checksum_sha256
  role             = aws_iam_role.route_handler[each.value.s3_key].arn
}

resource "aws_lambda_permission" "apigw_trigger" {
  for_each = {
    for route_handler in local.route_handlers : route_handler.s3_key => route_handler
  }

  statement_id = format(
    "AllowExecutionFromAPIGateway-%s-%s",
    local.is_ws ? "ws" : "http",
    aws_apigatewayv2_api.this.id,
  )
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.route_handler[each.key].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*"
}

resource "aws_apigatewayv2_integration" "this" {
  for_each = local.route_keys

  api_id = aws_apigatewayv2_api.this.id
  # see https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-api-integration-types.html
  integration_type = "AWS_PROXY"
  connection_type  = "INTERNET"
  # see https://stackoverflow.com/a/68912233
  integration_uri = format(
    "arn:aws:lambda:%s:%s:function:%s-%s-$${stageVariables.stage}-%s",
    local.region,
    local.account_id,
    local.is_ws ? "ws" : "http",
    aws_apigatewayv2_api.this.id,
    # This needs to match the replace() call in the aws_lambda_function.route_handler resource.
    replace(each.value, local.key_regex, "-"),
  )
  payload_format_version = local.is_ws ? "1.0" : "2.0"
}

resource "aws_apigatewayv2_route" "this" {
  for_each = local.route_keys

  api_id    = aws_apigatewayv2_api.this.id
  route_key = each.value
  target    = "integrations/${aws_apigatewayv2_integration.this[each.value].id}"
  # Lambda authorizers can only be used on HTTP routes or the WebSocket $connect route.
  authorization_type = var.authorizer == null || (local.is_ws && each.value != "$connect") ? "NONE" : "CUSTOM"
  authorizer_id      = var.authorizer == null || (local.is_ws && each.value != "$connect") ? null : aws_apigatewayv2_authorizer.this[0].id
}
