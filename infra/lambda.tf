# --- Lambda deployment packages ---

data "archive_file" "task_created_handler" {
  type        = "zip"
  source_file = "${path.root}/../lambda/task_created_handler.py"
  output_path = "${path.root}/../lambda/task_created_handler.zip"
}

data "archive_file" "task_completed_handler" {
  type        = "zip"
  source_file = "${path.root}/../lambda/task_completed_handler.py"
  output_path = "${path.root}/../lambda/task_completed_handler.zip"
}

data "archive_file" "task_cleanup_handler" {
  type        = "zip"
  source_file = "${path.root}/../lambda/task_cleanup_handler.py"
  output_path = "${path.root}/../lambda/task_cleanup_handler.zip"
}

# --- task_created_handler (SQS trigger, no VPC) ---

resource "aws_lambda_function" "task_created_handler" {
  function_name    = "${local.prefix}-task-created-handler"
  role             = aws_iam_role.lambda_task_created.arn
  handler          = "task_created_handler.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.task_created_handler.output_path
  source_code_hash = data.archive_file.task_created_handler.output_base64sha256
  timeout          = 30
  memory_size      = 128

  depends_on = [aws_cloudwatch_log_group.lambda_task_created]

  tags = {
    Name    = "${local.prefix}-task-created-handler"
    Project = var.project_name
  }
}

# --- task_completed_handler (EventBridge trigger, no VPC) ---

resource "aws_lambda_function" "task_completed_handler" {
  function_name    = "${local.prefix}-task-completed-handler"
  role             = aws_iam_role.lambda_task_completed.arn
  handler          = "task_completed_handler.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.task_completed_handler.output_path
  source_code_hash = data.archive_file.task_completed_handler.output_base64sha256
  timeout          = 30
  memory_size      = 128

  depends_on = [aws_cloudwatch_log_group.lambda_task_completed]

  tags = {
    Name    = "${local.prefix}-task-completed-handler"
    Project = var.project_name
  }
}

# --- task_cleanup_handler (Scheduler trigger, VPC 内) ---

resource "aws_security_group" "lambda_cleanup" {
  name        = "${local.prefix}-lambda-cleanup-sg"
  description = "Security group for task cleanup Lambda (VPC)"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name    = "${local.prefix}-lambda-cleanup-sg"
    Project = var.project_name
  }
}

resource "aws_security_group_rule" "lambda_cleanup_to_rds" {
  type                     = "egress"
  from_port                = var.db_port
  to_port                  = var.db_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.lambda_cleanup.id
  source_security_group_id = aws_security_group.rds.id
  description              = "RDS access from cleanup Lambda"
}

resource "aws_security_group_rule" "lambda_cleanup_to_vpce" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.lambda_cleanup.id
  source_security_group_id = aws_security_group.vpc_endpoint.id
  description              = "VPC Endpoint access from cleanup Lambda"
}

# RDS SG に cleanup Lambda からのアクセスを追加
resource "aws_security_group_rule" "rds_from_lambda_cleanup" {
  type                     = "ingress"
  from_port                = var.db_port
  to_port                  = var.db_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = aws_security_group.lambda_cleanup.id
  description              = "PostgreSQL from cleanup Lambda"
}

resource "aws_lambda_function" "task_cleanup_handler" {
  function_name    = "${local.prefix}-task-cleanup-handler"
  role             = aws_iam_role.lambda_task_cleanup.arn
  handler          = "task_cleanup_handler.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.task_cleanup_handler.output_path
  source_code_hash = data.archive_file.task_cleanup_handler.output_base64sha256
  timeout          = 60
  memory_size      = 256
  layers           = [var.psycopg2_layer_arn]

  vpc_config {
    subnet_ids         = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_group_ids = [aws_security_group.lambda_cleanup.id]
  }

  environment {
    variables = {
      DB_SECRET_ARN          = aws_secretsmanager_secret.db_credentials.arn
      CLEANUP_RETENTION_DAYS = tostring(var.cleanup_retention_days)
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_task_cleanup]

  tags = {
    Name    = "${local.prefix}-task-cleanup-handler"
    Project = var.project_name
  }
}

# --- Lambda permissions ---

# EventBridge → task_completed_handler
resource "aws_lambda_permission" "task_completed_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.task_completed_handler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.task_completed.arn
}

# Scheduler → task_cleanup_handler
resource "aws_lambda_permission" "task_cleanup_scheduler" {
  statement_id  = "AllowSchedulerInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.task_cleanup_handler.function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = aws_scheduler_schedule.task_cleanup.arn
}
