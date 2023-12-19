resource "aws_acm_certificate" "this" {
  count = var.domain != null ? 1 : 0

  domain_name       = var.domain
  validation_method = "DNS"
}

resource "aws_apigatewayv2_domain_name" "this" {
  count = var.domain != null ? 1 : 0

  domain_name = var.domain
  domain_name_configuration {
    certificate_arn = aws_acm_certificate.this[0].arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}
