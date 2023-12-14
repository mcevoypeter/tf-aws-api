#
# aws_apigatewayv2_api resource
#

output "api_id" {
  description = "ID of API."
  value       = aws_apigatewayv2_api.this.id
}

output "api_arn" {
  description = "ARN of API."
  value       = aws_apigatewayv2_api.this.arn
}

output "api_endpoint" {
  description = "URI of API."
  value       = aws_apigatewayv2_api.this.api_endpoint
}

output "api_execution_arn" {
  description = "See https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_api#execution_arn."
  value       = aws_apigatewayv2_api.this.execution_arn
}

#
# aws_iam_role resources
#

output "lambda_role_ids" {
  description = "IDs of Lambda route handler IAM roles."
  value = [
    for role in aws_iam_role.route_handler : role.id
  ]
}

output "lambda_role_arns" {
  description = "ARNs of Lambda route handler IAM roles."
  value = [
    for role in aws_iam_role.route_handler : role.arn
  ]
}

output "lambda_role_names" {
  description = "Names of Lambda route handler IAM roles."
  value = [
    for role in aws_iam_role.route_handler : role.name
  ]
}

#
# aws_lambda_function resources
#

output "lambda_fn_arns" {
  description = "ARNs of Lambda route handler functions."
  value = [
    for fn in aws_lambda_function.route_handler : fn.arn
  ]
}

output "lambda_fn_names" {
  description = "Names of Lambda route handler functions."
  value = [
    for fn in aws_lambda_function.route_handler : fn.function_name
  ]
}

#
# aws_apigatewayv2_route resources
#

output "route_ids" {
  description = "IDs of API Gateway routes."
  value = [
    for route in aws_apigatewayv2_route.this : route.id
  ]
}

output "route_keys" {
  description = "Route keys of API Gateway routes."
  value = [
    for route in aws_apigatewayv2_route.this : route.route_key
  ]
}
