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

variable "stages" {
  description = "Stage names. Each must be between 1 and 128 characters in length."
  type        = set(string)
}

variable "routes" {
  description = "API routes"
  type = set(object({
    # Route key i.e. `GET /a/b/{id}`.
    key = string
    # Name of Lambda function that handles the route.
    function_name = string
    # Invocation ARN of the route-handling Lambda function.
    invoke_arn = string
  }))
}
