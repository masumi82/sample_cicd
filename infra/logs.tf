resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 14

  tags = {
    Name    = "${var.project_name}-logs"
    Project = var.project_name
  }
}

resource "aws_cloudwatch_log_group" "lambda_task_created" {
  name              = "/aws/lambda/${var.project_name}-task-created-handler"
  retention_in_days = var.lambda_log_retention_days

  tags = {
    Name    = "${var.project_name}-lambda-task-created-logs"
    Project = var.project_name
  }
}

resource "aws_cloudwatch_log_group" "lambda_task_completed" {
  name              = "/aws/lambda/${var.project_name}-task-completed-handler"
  retention_in_days = var.lambda_log_retention_days

  tags = {
    Name    = "${var.project_name}-lambda-task-completed-logs"
    Project = var.project_name
  }
}

resource "aws_cloudwatch_log_group" "lambda_task_cleanup" {
  name              = "/aws/lambda/${var.project_name}-task-cleanup-handler"
  retention_in_days = var.lambda_log_retention_days

  tags = {
    Name    = "${var.project_name}-lambda-task-cleanup-logs"
    Project = var.project_name
  }
}
