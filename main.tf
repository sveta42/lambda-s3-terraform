terraform {
  required_version = "1.3.6"
}
provider "aws" {
  region     = "eu-west-1"
}

//        lambda         



data "archive_file" "lambda_archive" {
  type        = "zip"
  source_file = "${path.module}/app.js"
  output_path = "${path.module}/app.js.zip"
}

resource "aws_lambda_function" "lambda_app" {
  function_name = "example-lambda"
  filename      = data.archive_file.lambda_archive.output_path
  role          = aws_iam_role.iam_for_lambda.arn
  runtime       = "nodejs14.x"
  handler       = "app.handler"

  source_code_hash = data.archive_file.lambda_archive.output_base64sha256

  vpc_config {
    subnet_ids          = aws_subnet.private_subnet.id
    security_group_ids  = aws_security_group.default.id
  }
} 

//        api gateway        



resource "aws_api_gateway_resource" "example_gateway_resource" {
  rest_api_id = aws_api_gateway_rest_api.example.id
  parent_id   = aws_api_gateway_rest_api.example.root_resource_id
  path_part   = "path_example"
}

resource "aws_api_gateway_method" "example_gateway_method" {
  rest_api_id   = aws_api_gateway_rest_api.example.id
  resource_id   = aws_api_gateway_resource.example_gateway_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "example_gateway_integration" {
  rest_api_id = aws_api_gateway_rest_api.example.id
  resource_id = aws_api_gateway_method.example_gateway_method.resource_id
  http_method = aws_api_gateway_method.example_gateway_method.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_app.invoke_arn
}

resource "aws_api_gateway_rest_api" "example" {
  body = jsonencode({
    openapi = "3.0.1"
    info = {
      title   = "example"
      version = "1.0"
    }
    paths = {
      "/path1" = {
        get = {
          x-amazon-apigateway-integration = {
            httpMethod           = "GET"
            payloadFormatVersion = "1.0"
            type                 = "HTTP_PROXY"
            uri                  = "https://ip-ranges.amazonaws.com/ip-ranges.json"
          }
        }
      }
    }
  })

  name = "example"
}

resource "aws_api_gateway_deployment" "example" {
  rest_api_id = aws_api_gateway_rest_api.example.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.example_gateway_resource.id,
      aws_api_gateway_method.example_gateway_method.id,
      aws_api_gateway_integration.example_gateway_integration.id,
    ]))

  }
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "example" {
  deployment_id = aws_api_gateway_deployment.example.id
  rest_api_id   = aws_api_gateway_rest_api.example.id
  stage_name    = "example"
}

//        s3        

resource "aws_s3_bucket" "lambda-server-s3" {
  bucket  = "my-bucket" 
  tags = {
    Name        = "devops-bucket"
  }
}

#acl - access control lists - for bucket
resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket = aws_s3_bucket.lambda-server-s3.id
  acl    = "private"
}

# Upload an object
resource "aws_s3_bucket_object" "object" {
  bucket = aws_s3_bucket.lambda-server-s3.id
  key    = "app.js.zip"
  acl    = "private"
  source = "./app.js.zip"
}


resource "aws_lambda_permission" "lambda_permission" {
  statement_id  = "AllowMyDemoAPIInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_app.function_name
  principal     = "apigateway.amazonaws.com"

  # The /*/*/* part allows invocation from any stage, method and resource path
  # within API Gateway REST API.
  source_arn = "${aws_api_gateway_rest_api.example.execution_arn}/*/*/*"
}

