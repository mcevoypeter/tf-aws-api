output "api" {
  description = "API Gateway API"
  value = {
    id            = aws_apigatewayv2_api.this.id,
    arn           = aws_apigatewayv2_api.this.arn,
    endpoint      = var.domain_id != null ? var.domain_id : aws_apigatewayv2_api.this.api_endpoint,
    execution_arn = aws_apigatewayv2_api.this.execution_arn,
  }
}

output "route_handler_iam_roles" {
  description = "IAM roles for the Lambda route handlers."
  value = [
    for role in aws_iam_role.route_handler : {
      id   = role.id,
      arn  = role.arn,
      name = role.name,
    }
  ]
}

output "authorizer_iam_role" {
  description = "IAM role for the Lambda authorizer."
  value = var.authorizer != null ? {
    id   = aws_iam_role.authorizer[0].id,
    arn  = aws_iam_role.authorizer[0].arn,
    name = aws_iam_role.authorizer[0].name,
  } : null
}

output "route_handler_fns" {
  description = "Lambda route handler functions."
  value = [
    for fn in aws_lambda_function.route_handler : {
      arn  = fn.arn,
      name = fn.function_name,
    }
  ]
}

output "authorizer_fn" {
  description = "Lambda authorizer function."
  value = var.authorizer != null ? {
    arn  = aws_lambda_function.authorizer[0].arn,
    name = aws_lambda_function.authorizer[0].function_name,
  } : null
}

output "routes" {
  description = "API Gateway routes."
  value = [
    for route in aws_apigatewayv2_route.this : {
      id        = route.id,
      route_key = route.route_key,
    }
  ]
}
