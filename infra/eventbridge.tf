# カスタムイベントバス
resource "aws_cloudwatch_event_bus" "main" {
  name = "${var.project_name}-bus"

  tags = {
    Name    = "${var.project_name}-bus"
    Project = var.project_name
  }
}

# TaskCompleted イベントのルール
resource "aws_cloudwatch_event_rule" "task_completed" {
  name           = "${var.project_name}-task-completed"
  event_bus_name = aws_cloudwatch_event_bus.main.name

  event_pattern = jsonencode({
    source      = ["sample-cicd"]
    detail-type = ["TaskCompleted"]
  })

  tags = {
    Name    = "${var.project_name}-task-completed-rule"
    Project = var.project_name
  }
}

# ルールのターゲット → task_completed_handler Lambda
resource "aws_cloudwatch_event_target" "task_completed_lambda" {
  rule           = aws_cloudwatch_event_rule.task_completed.name
  event_bus_name = aws_cloudwatch_event_bus.main.name
  target_id      = "task-completed-lambda"
  arn            = aws_lambda_function.task_completed_handler.arn
}

# EventBridge Scheduler 用 IAM ロール
resource "aws_iam_role" "scheduler_task_cleanup" {
  name = "${var.project_name}-scheduler-task-cleanup"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "scheduler.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name    = "${var.project_name}-scheduler-task-cleanup"
    Project = var.project_name
  }
}

resource "aws_iam_role_policy" "scheduler_task_cleanup" {
  name = "${var.project_name}-scheduler-invoke-lambda"
  role = aws_iam_role.scheduler_task_cleanup.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = aws_lambda_function.task_cleanup_handler.arn
      }
    ]
  })
}

# 定期クリーンアップスケジュール（毎日 0:00 JST = 15:00 UTC）
resource "aws_scheduler_schedule" "task_cleanup" {
  name       = "${var.project_name}-task-cleanup"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = var.cleanup_schedule_expression
  schedule_expression_timezone = "Asia/Tokyo"

  target {
    arn      = aws_lambda_function.task_cleanup_handler.arn
    role_arn = aws_iam_role.scheduler_task_cleanup.arn
  }
}
