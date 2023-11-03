output "api_id" {
  description = "ID of API"
  value       = aws_apigatewayv2_api.this.id
}

output "api_arn" {
  description = "ARN of API"
  value       = aws_apigatewayv2_api.this.arn
}
