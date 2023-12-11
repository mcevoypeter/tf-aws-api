#
# aws_apigatewayv2_api resource
#

output "api_id" {
  description = "ID of API"
  value       = aws_apigatewayv2_api.this.id
}

output "api_arn" {
  description = "ARN of API"
  value       = aws_apigatewayv2_api.this.arn
}

output "api_endpoint" {
  description = " URI of API"
  value       = aws_apigatewayv2_api.this.api_endpoint
}

output "api_execution_arn" {
  description = "See https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_api#execution_arn"
  value       = aws_apigatewayv2_api.this.execution_arn
}

#
# aws_iam_role resources
#

output "lambda_role_ids" {
  description = "IDs of Lambda IAM roles."
  value = [
    for role in aws_iam_role.this : role.id
  ]
}

output "lambda_role_arns" {
  description = "ARNs of Lambda IAM roles."
  value = [
    for role in aws_iam_role.this : role.arn
  ]
}

output "lambda_role_names" {
  description = "Names of Lambda IAM roles."
  value = [
    for role in aws_iam_role.this : role.name
  ]
}
