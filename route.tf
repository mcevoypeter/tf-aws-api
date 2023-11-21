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

resource "aws_iam_role" "this" {
  for_each = {
    for idx, route in var.routes : route.route_key => route
  }

  name               = "Lambda-${each.value.function_name}"
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
  inline_policy {
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
  dynamic "inline_policy" {
    for_each = each.value.inline_policies
    content {
      name   = inline_policy.value["name"]
      policy = inline_policy.value["policy"]
    }
  }
}

resource "aws_lambda_function" "this" {
  for_each = {
    for idx, route in var.routes : route.route_key => route
  }

  s3_bucket     = var.functions_s3_bucket
  s3_key        = each.value.s3_key
  function_name = each.value.function_name
  runtime       = each.value.runtime
  handler       = "handler"
  role          = aws_iam_role.this[each.key].arn
}


resource "aws_lambda_permission" "apigw_trigger" {
  for_each = {
    for idx, route in var.routes : route.route_key => route
  }

  statement_id  = "AllowExecutionFromAPIGateway-${var.name}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*"
}

resource "aws_apigatewayv2_integration" "this" {
  for_each = {
    for idx, route in var.routes : route.route_key => route
  }

  api_id = aws_apigatewayv2_api.this.id
  # see https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-api-integration-types.html
  integration_type = "AWS_PROXY"
  connection_type  = "INTERNET"
  integration_uri  = aws_lambda_function.this[each.key].invoke_arn
}

resource "aws_apigatewayv2_route" "this" {
  for_each = {
    for idx, route in var.routes : route.route_key => route
  }

  api_id    = aws_apigatewayv2_api.this.id
  route_key = each.key
  target    = "integrations/${aws_apigatewayv2_integration.this[each.key].id}"
}