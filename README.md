# [AWS] [API Gateway]

This [Terraform] module creates an [AWS] [API Gateway] API. It supports both [HTTP][http-api] and [WebSocket][ws-api] APIs.

## Prequisites

### [Lambda]

This module does not handle the creation of [Lambda] functions. Before creating an API with this module, ensure all [Lambda] functions and their corresponding [IAM] roles have been created using the [tf-aws-lambda] [Terraform] module.

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
      key           = "POST /user"
      function-name = "add-user"
      invoke_arn    = "arn:aws:lambda:us-east-2:012345678901:function:add-user"
    },
    {
      key           = "GET /user/{id}"
      function_name = "get-user"
      invoke_arn    = "arn:aws:lambda:us-east-2:012345678901:function:get-user"
    },
    {
      key           = "DELETE /user/{id}"
      function_name = "remove-user"
      invoke_arn    = "arn:aws:lambda:us-east-2:012345678901:function:remove-user"
    },
  ]
}
```

Once deployed, this API can be invoked via `curl`:

```console
curl https://<api_id>.execute-api.us-east-2.amazonaws.com/v0/user/<user_id>
```

### [WebSocket][ws-api]

The following use of this module creates a [WebSocket API][ws-api] named `example_ws` in `us-west-1` with stages (`v0` and `v1`) and routes `$default` (the default route) and `info`.

```terraform
module "ws_api" {
  source        = "git@github.com:mcevoypeter/tf-aws-api.git"
  region        = "us-west-1"
  name          = "example_ws"
  protocol_type = "WEBSOCKET"
  stages        = ["v0", "v1"]
  routes = [
    {
      key           = "$default"
      function_name = "default-handler"
      invoke_arn    = "arn:aws:lambda:us-east-2:828118291497:function:default-handler"
    },
    {
      key           = "info"
      function_name = "info-handler"
      invoke_arn    = "arn:aws:lambda:us-east-2:828118291497:function:info-handler"
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
[tf-aws-lambda]: https://github.com/palm-drive/tf-aws-lambda
[ws-api]: https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-websocket-api.html
