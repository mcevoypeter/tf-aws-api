variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name of API Gateway API."
  type        = string
}

variable "protocol_type" {
  description = "Type of API. Valid values: `HTTP`, `WEBSOCKET`."
  type        = string
}
