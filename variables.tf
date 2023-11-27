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

variable "functions_s3_bucket" {
  description = "S3 bucket containing Lambda route handlers"
  type        = string
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
    route_key = string
    # Key of Lambda route handler in functions_s3_bucket. See
    # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function#s3_key.
    s3_key = string
    # Name of Lambda route handler created from s3_key. The function entrypoint
    # MUST be named `handler`.
    function_name = string
    # Runtime of Lambda route handler. See
    # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function#runtime.
    runtime = string
    # Handler name. For JavaScript and TypeScript handlers, this is
    # `<module>.<handler>` i.e. `example.handler` for a handler named `handler`
    # defined in a file `example.ts`.
    handler = string
    # Format of the payload sent to the Lambda route handler. Must be either `1.0`
    # or `2.0` for HTTP APIs and `1.0` for WebSocket APIs (see
    # https://github.com/hashicorp/terraform-provider-aws/issues/25280).
    payload_format_version = string
    # ARNs of permission policies to grant to the Lambda route handler.
    policy_arns = list(string)
    # Inline policies to grant to the Lambda route handler. See
    # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role#inline_policy.
    inline_policies = set(object({ name = string, policy = string }))
  }))
}
