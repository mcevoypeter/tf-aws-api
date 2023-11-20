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
