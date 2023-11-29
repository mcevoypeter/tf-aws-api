# [AWS] [API Gateway]

This [Terraform] module creates an [AWS] [API Gateway] API. It supports both [HTTP][http-api] and [WebSocket][ws-api] APIs. For both API types, it uses [payload format version 2.0](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-develop-integrations-lambda.html#http-api-develop-integrations-lambda.proxy-format).

## Prequisites

### [CloudWatch] Logging

To enable the API to write [execution logs](https://docs.aws.amazon.com/apigateway/latest/developerguide/set-up-logging.html) to [CloudWatch], the [AWS] account in which the API is deployed needs an [IAM] role that grants [API Gateway] push access to [CloudWatch], and [API Gateway] needs to be configured with the [ARN] of that [IAM] role. Because [CloudWatch] logging from [API Gateway] is configured at the level of an [AWS] account, not an API, it's omitted from this module.

The following code both creates the [IAM] role and configures [API Gateway] to use the role for [CloudWatch] logging:

```terraform
data "aws_iam_policy_document" "allow_cloudwatch_access_from_apigw" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "logger" {
  name                = "APIGatewayLogger"
  assume_role_policy  = data.aws_iam_policy_document.allow_cloudwatch_access_from_apigw.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"]
}

# Enable API Gateway to write logs to CloudWatch.
resource "aws_api_gateway_account" "this" {
  cloudwatch_role_arn = aws_iam_role.logger.arn
}
```

**Note:** [HTTP APIs][http-api] do not produce execution logs. See [this Stack Overflow post](https://stackoverflow.com/a/62546187) for an explanation.

## Inputs

See [`variables.tf`](variables.tf).

## Outputs

See [`output.tf`](output.tf).

## Example

### [HTTP][http-api]

The following use of this module creates an [HTTP API][http-api] named `example_http` in `us-east-2` with a single stage `v0` and three routes, each connected to a separate [Lambda] function.

```terraform
module "http_api" {
  source        = "git@github.com:mcevoypeter/tf-aws-api.git"
  region        = "us-east-2"
  name          = "example_http"
  protocol_type = "HTTP"
  stages        = ["v0"]
  routes = [
    {
      route_key       = "POST /user"
      s3_key          = "add-user.zip"
      function_name   = "add-user"
      runtime         = "nodejs20.x"
      handler         = "handler"
      policy_arns     = []
      inline_policies = []
    },
    {
      key             = "GET /user/{id}"
      s3_key          = "get-user.zip"
      function_name   = "get-user"
      runtime         = "nodejs20.x"
      handler         = "handler"
      policy_arns     = []
      inline_policies = []
    },
    {
      key             = "DELETE /user/{id}"
      s3_key          = "remove-user.zip"
      function_name   = "remove-user"
      handler         = "handler"
      runtime         = "nodejs20.x"
      policy_arns     = []
      inline_policies = []
    },
  ]
}
```

Once deployed, this API can be invoked via `curl`:

```console
curl https://<api_id>.execute-api.us-east-2.amazonaws.com/v0/user/<user_id>
```

### [WebSocket][ws-api]

The following use of this module creates a [WebSocket API][ws-api] named `example_ws` in `us-west-1` with stages (`v0` and `v1`) and routes `$default` (the default route) and `info`, each connected to a single [Lambda] function.

```terraform
module "ws_api" {
  source        = "git@github.com:mcevoypeter/tf-aws-api.git"
  region        = "us-west-1"
  name          = "example_ws"
  protocol_type = "WEBSOCKET"
  stages        = ["v0", "v1"]
  routes = [
    {
      key             = "$default"
      s3_key          = "default-handler.zip"
      function_name   = "default-handler"
      runtime         = "nodejs20.x"
      handler         = "default-handler.handler"
      policy_arns     = []
      inline_policies = []
    },
    {
      key             = "info"
      s3_key          = "info-handler.zip"
      function_name   = "info-handler"
      runtime         = "nodejs20.x"
      handler         = "info-handler.handler"
      policy_arns     = []
      inline_policies = []
    },
  ]

}
```

Once deployed, this API can be invoked via [`wscat`](https://github.com/websockets/wscat):

```console
wscat --connect https://<api_id>.execute-api.us-west-1.amazonaws.com/v0/
> { "action": "$default" }
<response from default-handler>
> { "action": "info" }
<response form info-handler>
```

[API Gateway]: https://aws.amazon.com/api-gateway
[ARN]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference-arns.html
[AWS]: https://aws.amazon.com/
[CloudWatch]: https://aws.amazon.com/cloudwatch/
[http-api]: https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api.html
[IAM]: https://aws.amazon.com/iam/
[Lambda]: https://aws.amazon.com/lambda/
[S3]: https://aws.amazon.com/s3/
[Terraform]: https://www.terraform.io/
[ws-api]: https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-websocket-api.html
