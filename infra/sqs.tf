# Dead Letter Queue — リトライ上限到達後のメッセージを退避する
resource "aws_sqs_queue" "task_events_dlq" {
  name                      = "${local.prefix}-task-events-dlq"
  message_retention_seconds = 1209600 # 14 days

  tags = {
    Name    = "${local.prefix}-task-events-dlq"
    Project = var.project_name
  }
}

# Main Queue — タスク作成イベントを受け付ける
resource "aws_sqs_queue" "task_events" {
  name = "${local.prefix}-task-events"

  # Lambda タイムアウト (30s) の 2 倍に設定（SQS ベストプラクティス）
  visibility_timeout_seconds = 60
  message_retention_seconds  = 86400 # 1 day

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.task_events_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name    = "${local.prefix}-task-events"
    Project = var.project_name
  }
}

# ECS タスクロールから SendMessage を許可
resource "aws_sqs_queue_policy" "task_events" {
  queue_url = aws_sqs_queue.task_events.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.ecs_task.arn }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.task_events.arn
      }
    ]
  })
}

# SQS → Lambda イベントソースマッピング
resource "aws_lambda_event_source_mapping" "task_created" {
  event_source_arn = aws_sqs_queue.task_events.arn
  function_name    = aws_lambda_function.task_created_handler.arn
  batch_size       = 1 # 1 メッセージずつ処理（学習用途）
  enabled          = true
}
