locals {
  authorizer_name = "${aws_apigatewayv2_api.this.id}-api-authorizer"
}

resource "aws_iam_role" "authorizer" {
  count = var.authorizer != null ? 1 : 0

  name               = "Lambda-${local.authorizer_name}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  managed_policy_arns = [
    # permissions required to invoke the function
    "arn:aws:iam::aws:policy/service-role/AWSLambdaRole",
    # permissions required to write logs to CloudWatch
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
  ]
}

data "aws_s3_object" "authorizer" {
  count = var.authorizer != null ? 1 : 0

  bucket        = var.handlers_s3_bucket
  key           = var.authorizer.s3_key
  checksum_mode = "ENABLED"
}

resource "aws_lambda_function" "authorizer" {
  count = var.authorizer != null ? 1 : 0

  s3_bucket        = var.handlers_s3_bucket
  s3_key           = var.authorizer.s3_key
  function_name    = local.authorizer_name
  runtime          = var.authorizer.runtime
  handler          = var.authorizer.entrypoint
  source_code_hash = data.aws_s3_object.authorizer[0].checksum_sha256
  role             = aws_iam_role.authorizer[0].arn
}

resource "aws_lambda_permission" "authorizer_apigw_trigger" {
  count = var.authorizer != null ? 1 : 0

  statement_id  = "AllowExecutionFromAPIGateway-${local.authorizer_name}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.authorizer[0].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*"
}

resource "aws_apigatewayv2_authorizer" "this" {
  count = var.authorizer != null ? 1 : 0

  api_id           = aws_apigatewayv2_api.this.id
  authorizer_type  = var.authorizer.type
  authorizer_uri   = aws_lambda_function.authorizer[0].invoke_arn
  identity_sources = []
  name             = local.authorizer_name
  # This attribute can only be set for HTTP APIs, not WebSocket APIs.
  authorizer_payload_format_version = local.is_ws ? null : "2.0"
}
