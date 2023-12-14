# [AWS] [API Gateway]

[![MIT license](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE.txt)

This [Terraform] module creates an [AWS] [API Gateway] API and [AWS] [Lambda]-handled routes.

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

## Payload Formats

[HTTP APIs][http-api] use payload format version 2.0 whereas [WebSocket APIs][ws-api] use payload format version 1.0. See this [GitHub issue](https://github.com/hashicorp/terraform-provider-aws/issues/25280) and the [AWS docs](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-develop-integrations-lambda.html#http-api-develop-integrations) for more information.

## Deploying Source Code Zip Archives

When uploading a source code zip archive to the [S3] bucket that hosts the API's route handlers, the SHA256 checksum of the zip archive **must** be supplied so that [Terraform] can properly track changes made to each route handlers source code and redeploy the corresponding [Lambda]s as necessary. To do so, use the [`aws s3api put-object`](https://docs.aws.amazon.com/AmazonS3/latest/userguide/checking-object-integrity.html) of the [AWS CLI]:

```console
aws s3api put-object \
    --bucket <bucket> \
    --key <object_key> \
    --body <path_to_deployment_archive> \
    --checksum-algorithm sha256 \
    --checksum-sha256 $(openssl dgst -binary -sha256 <path_to_deployment_archive> | openssl base64)
```

To check the SHA256 checksum of a given source code zip archive after uploading:

```console
aws s3api get-object-attributes \
    --bucket <bucket> \
    --key <object_key> \
    --object-attributes Checksum
```

## Example

### [HTTP][http-api]

The following use of this module creates an [HTTP API][http-api] named `example_http` in `us-east-2` with two stages `v0` and `v1` and a single route `GET /example`.

```terraform
module "http_api" {
  source        = "git@github.com:mcevoypeter/tf-aws-api.git"
  region        = "us-east-2"
  name          = "example_http"
  protocol_type = "HTTP"
  handlers_s3_bucket = "api-route-handlers"
  stages = {
    "v0" = [
      {
        route_key   = "GET /example"
        s3_key      = "http/v0/example.zip"
        runtime     = "provided.al2023"
        entrypoint  = "main"
        policy_arns = ["arn:aws:iam::aws:policy/AmazonS3FullAccess"]
        inline_policies = [
          {
            name = "DynamoDB-BogusTable"
            policy = jsonencode({
              Version = "2012-10-17"
              Statement = [
                {
                  Action = [
                    "dynamodb:DeleteItem",
                    "dynamodb:GetItem",
                    "dynamodb:PutItem",
                    "dynamodb:Query",
                  ]
                  Effect   = "Allow"
                  Resource = "arn:aws:dynamodb:*:012345678901:table/BogusTable"
                },
                {
                  Effect   = "Allow"
                  Action   = ["dynamodb:Query"]
                  Resource = "arn:aws:dynamodb:*:012345678901:table/BogusTable/index/*"
                }
              ]
            })
          },
        ]
      },
    ],
    "v1" = [
      {
        route_key   = "GET /example"
        s3_key      = "http/v1/example.zip"
        runtime     = "provided.al2023"
        entrypoint  = "main"
        policy_arns = ["arn:aws:iam::aws:policy/AmazonS3FullAccess"]
        inline_policies = [
          {
            name = "DynamoDB-BogusTable"
            policy = jsonencode({
              Version = "2012-10-17"
              Statement = [
                {
                  Action = [
                    "dynamodb:DeleteItem",
                    "dynamodb:GetItem",
                    "dynamodb:PutItem",
                    "dynamodb:Query",
                  ]
                  Effect   = "Allow"
                  Resource = "arn:aws:dynamodb:*:012345678901:table/BogusTable"
                },
                {
                  Effect   = "Allow"
                  Action   = ["dynamodb:Query"]
                  Resource = "arn:aws:dynamodb:*:012345678901:table/BogusTable/index/*"
                },
              ]
            })
          },
        ]
      },
    ],
  }
}
```

Once deployed, this API can be invoked via `curl`:

```console
curl https://<api_id>.execute-api.us-east-2.amazonaws.com/v0/example
# response from Lambda function v0-http-example sourced from s3://api-route-handlers/http/v0/example.zip

curl https://<api_id>.execute-api.us-east-2.amazonaws.com/v1/example
# response from Lambda function v1-http-example sourced from s3://api-route-handlers/http/v1/example.zip
```

### [WebSocket][ws-api]

The following use of this module creates a [WebSocket API][ws-api] named `example_ws` in `us-west-1` with stages `v0` and `v1` and a single route `example` authorized by a [request authorizer](https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-use-lambda-authorizer.html#api-gateway-lambda-authorizer-lambda-function-create) defined in `bootstrap` of the zip archive at `s3://api-route-handlers/ws/authorizer.zip`:

```terraform
module "ws_api" {
  source        = "git@github.com:mcevoypeter/tf-aws-api.git"
  region        = "us-west-1"
  name          = "example_ws"
  protocol_type = "WEBSOCKET"
  handlers_s3_bucket = "api-route-handlers"
  authorizer = {
    type       = "REQUEST",
    s3_key     = "ws/authorizer.zip",
    runtime    = "provided.al2023",
    entrypoint = "main",
  }
  stages = {
    "v0" = [
      {
        route_key       = "example"
        s3_key          = "ws/v0/example.zip"
        runtime         = "provided.al2023"
        entrypoint      = "main"
        policy_arns     = ["arn:aws:iam::aws:policy/SecretsManagerReadWrite"]
        inline_policies = []
      },
    ],
    "v1" = [
      {
        route_key       = "example"
        s3_key          = "ws/v1/example.zip"
        runtime         = "provided.al2023"
        entrypoint      = "main"
        policy_arns     = ["arn:aws:iam::aws:policy/SecretsManagerReadWrite"]
        inline_policies = []
      },
    ],
  }
}
```

Once deployed, this API can be invoked via [`wscat`](https://github.com/websockets/wscat):

```console
wscat --connect https://<api_id>.execute-api.us-west-1.amazonaws.com/v0/
> { "action": "example" }
<response from Lambda function sourced from s3://api-route-handlers/ws/v0/example.zip>

wscat --connect https://<api_id>.execute-api.us-west-1.amazonaws.com/v1/
> { "action": "example" }
<response from Lambda function sourced from s3://api-route-handlers/ws/v1/example.zip>
```

## License

This project is licensed under the terms of the [MIT license](https://en.wikipedia.org/wiki/MIT_License).

[API Gateway]: https://aws.amazon.com/api-gateway
[ARN]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference-arns.html
[AWS]: https://aws.amazon.com/
[AWS CLI]: https://aws.amazon.com/cli/
[CloudWatch]: https://aws.amazon.com/cloudwatch/
[http-api]: https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api.html
[IAM]: https://aws.amazon.com/iam/
[Lambda]: https://aws.amazon.com/lambda/
[S3]: https://aws.amazon.com/s3/
[Terraform]: https://www.terraform.io/
[ws-api]: https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-websocket-api.html
