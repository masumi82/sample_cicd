resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${local.prefix}"
  retention_in_days = var.log_retention_days

  tags = {
    Name    = "${local.prefix}-logs"
    Project = var.project_name
  }
}

resource "aws_cloudwatch_log_group" "lambda_task_created" {
  name              = "/aws/lambda/${local.prefix}-task-created-handler"
  retention_in_days = var.lambda_log_retention_days

  tags = {
    Name    = "${local.prefix}-lambda-task-created-logs"
    Project = var.project_name
  }
}

resource "aws_cloudwatch_log_group" "lambda_task_completed" {
  name              = "/aws/lambda/${local.prefix}-task-completed-handler"
  retention_in_days = var.lambda_log_retention_days

  tags = {
    Name    = "${local.prefix}-lambda-task-completed-logs"
    Project = var.project_name
  }
}

resource "aws_cloudwatch_log_group" "lambda_task_cleanup" {
  name              = "/aws/lambda/${local.prefix}-task-cleanup-handler"
  retention_in_days = var.lambda_log_retention_days

  tags = {
    Name    = "${local.prefix}-lambda-task-cleanup-logs"
    Project = var.project_name
  }
}

# v6: X-Ray daemon sidecar log group
resource "aws_cloudwatch_log_group" "xray" {
  name              = "/ecs/${local.prefix}-xray"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${local.prefix}-xray-logs"
    Project     = var.project_name
    Environment = local.env
  }
}
