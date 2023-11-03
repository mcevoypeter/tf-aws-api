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
    # Route key. A valid HTTP route key is of the form `<http_method> <path>`
    # i.e. `GET /a/{id}`. A valid WebSocket route key is of the form `<action>`
    # i.e. `update`. For more on HTTP route keys, see
    # https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-develop-routes.html.
    # For more on WebSocket route keys, see
    # https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-websocket-api-routes-integrations.html.
    key = string
    # Name of Lambda function that handles the route.
    function_name = string
    # Invocation ARN of the route-handling Lambda function.
    invoke_arn = string
  }))
}
