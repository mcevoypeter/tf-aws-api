variable "name" {
  description = "Name of API Gateway API."
  type        = string
}

variable "protocol_type" {
  description = "Type of API. Valid values: `HTTP`, `WEBSOCKET`."
  type        = string
}

variable "handlers_s3_bucket" {
  description = "S3 bucket containing Lambda route handlers"
  type        = string
}

variable "authorizer" {
  description = "Lambda authorizer sourced from `var.handlers_s3_bucket`."
  type = object({
    # The authorizer type. Either `TOKEN` or `REQUEST`.
    type = string,
    # Source of the authorizer zip archive in `var.handlers_s3_bucket`.
    s3_key = string,
    # Runtime of the authorizer.
    runtime = string,
    # Function entrypoint.
    entrypoint = string,
    # ARNs of permission policies to grant to the authorizer.
    policy_arns = list(string)
    # Inline policies to grant to the authorizer. See
    # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role#inline_policy.
    inline_policies = set(object({ name = string, policy = string }))
  })
  default = null
}

variable "stages" {
  description = <<EOT
Map from stage name to a stage's route handlers.

A valid stage name must be between 1 and 128 characters in length.

A stage's route handlers is a map from route key to route handler. A route
key's route handler specifies its source and the policies it needs to
operate. All route keys listed in a stage's route handlers' map must also
be defined in `var.routes`.
EOT
  type = map(set(object({
    # A valid HTTP route key is of the form `<http_method> <path>` i.e. `GET /a/{id}`.
    # A valid WebSocket route key is of the form `<action>` i.e. `update`. For more on
    # HTTP route keys, see
    # https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-develop-routes.html.
    # For more on WebSocket route keys, see
    # https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-websocket-api-routes-integrations.html.
    route_key = string
    # Source of route handler zip archive in `var.handlers_s3_bucket`. See
    # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function#s3_key.
    s3_key = string
    # Runtime of route handler. See
    # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function#runtime.
    runtime = string
    # Function entrypoint.
    entrypoint = string
    # ARNs of permission policies to grant to the route handler.
    policy_arns = list(string)
    # Inline policies to grant to the route handler. See
    # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role#inline_policy.
    inline_policies = set(object({ name = string, policy = string }))
  })))
}
