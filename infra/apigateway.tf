# --- v10: API Gateway REST API ---

# REST API
resource "aws_api_gateway_rest_api" "main" {
  name        = "${local.prefix}-api"
  description = "${local.prefix} REST API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name        = "${local.prefix}-api"
    Project     = var.project_name
    Environment = local.env
  }
}

# /api resource
resource "aws_api_gateway_resource" "api" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "api"
}

# /api/tasks resource
resource "aws_api_gateway_resource" "tasks" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = "tasks"
}

# /tasks/{proxy+} proxy resource
resource "aws_api_gateway_resource" "tasks_proxy" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.tasks.id
  path_part   = "{proxy+}"
}

# /tasks ANY method
resource "aws_api_gateway_method" "tasks" {
  rest_api_id      = aws_api_gateway_rest_api.main.id
  resource_id      = aws_api_gateway_resource.tasks.id
  http_method      = "ANY"
  authorization    = "NONE" #tfsec:ignore:aws-api-gateway-no-missing-authentication — CloudFront + WAF handles authentication
  api_key_required = true
}

# /tasks HTTP_PROXY integration
resource "aws_api_gateway_integration" "tasks" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.tasks.id
  http_method             = aws_api_gateway_method.tasks.http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  uri                     = "http://${aws_lb.main.dns_name}/tasks"
}

# /tasks/{proxy+} ANY method
resource "aws_api_gateway_method" "tasks_proxy" {
  rest_api_id      = aws_api_gateway_rest_api.main.id
  resource_id      = aws_api_gateway_resource.tasks_proxy.id
  http_method      = "ANY"
  authorization    = "NONE" #tfsec:ignore:aws-api-gateway-no-missing-authentication — CloudFront + WAF handles authentication
  api_key_required = true

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

# /tasks/{proxy+} HTTP_PROXY integration
resource "aws_api_gateway_integration" "tasks_proxy" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.tasks_proxy.id
  http_method             = aws_api_gateway_method.tasks_proxy.http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  uri                     = "http://${aws_lb.main.dns_name}/tasks/{proxy}"

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }

  cache_key_parameters = ["method.request.path.proxy"]
}

# Deployment
resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.api.id,
      aws_api_gateway_resource.tasks.id,
      aws_api_gateway_resource.tasks_proxy.id,
      aws_api_gateway_method.tasks.id,
      aws_api_gateway_method.tasks_proxy.id,
      aws_api_gateway_integration.tasks.id,
      aws_api_gateway_integration.tasks_proxy.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Stage (cache enabled)
resource "aws_api_gateway_stage" "main" {
  deployment_id         = aws_api_gateway_deployment.main.id
  rest_api_id           = aws_api_gateway_rest_api.main.id
  stage_name            = local.env
  cache_cluster_enabled = true
  cache_cluster_size    = "0.5"

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigw.arn
    format         = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      responseLength = "$context.responseLength"
      requestTime    = "$context.requestTime"
    })
  }

  tags = {
    Name        = "${local.prefix}-api-stage"
    Project     = var.project_name
    Environment = local.env
  }
}

# Method settings (caching + throttling)
resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  method_path = "*/*"

  settings {
    caching_enabled        = true
    cache_ttl_in_seconds   = var.apigw_cache_ttl
    throttling_rate_limit   = var.apigw_throttle_rate_limit
    throttling_burst_limit  = var.apigw_throttle_burst_limit
    metrics_enabled        = true
    logging_level          = "INFO"
  }
}

# Usage Plan
resource "aws_api_gateway_usage_plan" "main" {
  name = "${local.prefix}-usage-plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.main.id
    stage  = aws_api_gateway_stage.main.stage_name
  }

  throttle_settings {
    rate_limit  = var.apigw_throttle_rate_limit
    burst_limit = var.apigw_throttle_burst_limit
  }

  quota_settings {
    limit  = var.apigw_quota_limit
    period = var.apigw_quota_period
  }

  tags = {
    Name        = "${local.prefix}-usage-plan"
    Project     = var.project_name
    Environment = local.env
  }
}

# API Key
resource "aws_api_gateway_api_key" "main" {
  name    = "${local.prefix}-api-key"
  enabled = true

  tags = {
    Name        = "${local.prefix}-api-key"
    Project     = var.project_name
    Environment = local.env
  }
}

# API Key <-> Usage Plan association
resource "aws_api_gateway_usage_plan_key" "main" {
  key_id        = aws_api_gateway_api_key.main.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.main.id
}

# API Gateway account (CloudWatch logging)
resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.apigateway_cloudwatch.arn
}

# CloudWatch Logs group for API Gateway access logs
resource "aws_cloudwatch_log_group" "apigw" {
  name              = "/aws/apigateway/${local.prefix}-api"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${local.prefix}-apigw-logs"
    Project     = var.project_name
    Environment = local.env
  }
}
