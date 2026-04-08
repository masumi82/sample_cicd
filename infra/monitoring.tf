# --- v6: CloudWatch Dashboard + Alarms ---

# ============================
# CloudWatch Dashboard
# ============================

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # Row 1: ALB metrics
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ALB Request Count & 5xx Errors"
          region = var.aws_region
          period = 300
          stat   = "Sum"
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.main.arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", aws_lb.main.arn_suffix]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ALB Response Time & Healthy Hosts"
          region = var.aws_region
          period = 300
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.main.arn_suffix, { stat = "Average" }],
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", aws_lb_target_group.blue.arn_suffix,
            "LoadBalancer", aws_lb.main.arn_suffix, { stat = "Average" }]
          ]
        }
      },

      # Row 2: ECS metrics
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ECS CPU Utilization"
          region = var.aws_region
          period = 300
          stat   = "Average"
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.main.name,
            "ServiceName", aws_ecs_service.app.name]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ECS Memory Utilization"
          region = var.aws_region
          period = 300
          stat   = "Average"
          metrics = [
            ["AWS/ECS", "MemoryUtilization", "ClusterName", aws_ecs_cluster.main.name,
            "ServiceName", aws_ecs_service.app.name]
          ]
        }
      },

      # Row 3: RDS metrics
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 8
        height = 6
        properties = {
          title  = "RDS CPU Utilization"
          region = var.aws_region
          period = 300
          stat   = "Average"
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.main.identifier]
          ]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 12
        width  = 8
        height = 6
        properties = {
          title  = "RDS Free Storage Space"
          region = var.aws_region
          period = 300
          stat   = "Average"
          metrics = [
            ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", aws_db_instance.main.identifier]
          ]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 12
        width  = 8
        height = 6
        properties = {
          title  = "RDS Database Connections"
          region = var.aws_region
          period = 300
          stat   = "Average"
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", aws_db_instance.main.identifier]
          ]
        }
      },

      # Row 4: Lambda metrics
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 12
        height = 6
        properties = {
          title  = "Lambda Errors"
          region = var.aws_region
          period = 300
          stat   = "Sum"
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.task_created_handler.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.task_completed_handler.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.task_cleanup_handler.function_name]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 18
        width  = 12
        height = 6
        properties = {
          title  = "Lambda Duration"
          region = var.aws_region
          period = 300
          stat   = "Average"
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.task_created_handler.function_name],
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.task_completed_handler.function_name],
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.task_cleanup_handler.function_name]
          ]
        }
      },

      # Row 5: SQS metrics
      {
        type   = "metric"
        x      = 0
        y      = 24
        width  = 12
        height = 6
        properties = {
          title  = "SQS Messages (Main Queue)"
          region = var.aws_region
          period = 300
          stat   = "Sum"
          metrics = [
            ["AWS/SQS", "NumberOfMessagesSent", "QueueName", aws_sqs_queue.task_events.name],
            ["AWS/SQS", "NumberOfMessagesReceived", "QueueName", aws_sqs_queue.task_events.name],
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.task_events.name]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 24
        width  = 12
        height = 6
        properties = {
          title  = "SQS DLQ Messages"
          region = var.aws_region
          period = 300
          stat   = "Sum"
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.task_events_dlq.name]
          ]
        }
      }
    ]
  })
}

# ============================
# CloudWatch Alarms (12)
# ============================

# ALB 5xx Errors
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${local.prefix}-alb-5xx"
  alarm_description   = "ALB 5xx error count exceeds threshold"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.alarm_alb_5xx_threshold
  period              = 60
  evaluation_periods  = 3
  statistic           = "Sum"
  treat_missing_data  = "notBreaching"
  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }
  alarm_actions = [aws_sns_topic.alarm_notifications.arn]
  ok_actions    = [aws_sns_topic.alarm_notifications.arn]

  tags = {
    Project     = var.project_name
    Environment = local.env
  }
}

# ALB Unhealthy Hosts
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "${local.prefix}-alb-unhealthy-hosts"
  alarm_description   = "ALB has unhealthy hosts"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  period              = 60
  evaluation_periods  = 2
  statistic           = "Average"
  dimensions = {
    TargetGroup  = aws_lb_target_group.blue.arn_suffix
    LoadBalancer = aws_lb.main.arn_suffix
  }
  alarm_actions = [aws_sns_topic.alarm_notifications.arn]
  ok_actions    = [aws_sns_topic.alarm_notifications.arn]

  tags = {
    Project     = var.project_name
    Environment = local.env
  }
}

# ALB High Latency
resource "aws_cloudwatch_metric_alarm" "alb_high_latency" {
  alarm_name          = "${local.prefix}-alb-high-latency"
  alarm_description   = "ALB response time exceeds threshold"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.alarm_alb_latency_threshold
  period              = 60
  evaluation_periods  = 3
  statistic           = "Average"
  treat_missing_data  = "notBreaching"
  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }
  alarm_actions = [aws_sns_topic.alarm_notifications.arn]
  ok_actions    = [aws_sns_topic.alarm_notifications.arn]

  tags = {
    Project     = var.project_name
    Environment = local.env
  }
}

# ECS CPU High
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${local.prefix}-ecs-cpu-high"
  alarm_description   = "ECS CPU utilization exceeds threshold"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.alarm_ecs_cpu_threshold
  period              = 300
  evaluation_periods  = 2
  statistic           = "Average"
  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.app.name
  }
  alarm_actions = [aws_sns_topic.alarm_notifications.arn]
  ok_actions    = [aws_sns_topic.alarm_notifications.arn]

  tags = {
    Project     = var.project_name
    Environment = local.env
  }
}

# ECS Memory High
resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  alarm_name          = "${local.prefix}-ecs-memory-high"
  alarm_description   = "ECS memory utilization exceeds threshold"
  namespace           = "AWS/ECS"
  metric_name         = "MemoryUtilization"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.alarm_ecs_memory_threshold
  period              = 300
  evaluation_periods  = 2
  statistic           = "Average"
  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.app.name
  }
  alarm_actions = [aws_sns_topic.alarm_notifications.arn]
  ok_actions    = [aws_sns_topic.alarm_notifications.arn]

  tags = {
    Project     = var.project_name
    Environment = local.env
  }
}

# RDS CPU High
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${local.prefix}-rds-cpu-high"
  alarm_description   = "RDS CPU utilization exceeds threshold"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.alarm_rds_cpu_threshold
  period              = 300
  evaluation_periods  = 2
  statistic           = "Average"
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }
  alarm_actions = [aws_sns_topic.alarm_notifications.arn]
  ok_actions    = [aws_sns_topic.alarm_notifications.arn]

  tags = {
    Project     = var.project_name
    Environment = local.env
  }
}

# RDS Free Storage Low
resource "aws_cloudwatch_metric_alarm" "rds_free_storage_low" {
  alarm_name          = "${local.prefix}-rds-free-storage-low"
  alarm_description   = "RDS free storage space is below threshold"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  comparison_operator = "LessThanOrEqualToThreshold"
  threshold           = var.alarm_rds_free_storage_threshold
  period              = 300
  evaluation_periods  = 1
  statistic           = "Average"
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }
  alarm_actions = [aws_sns_topic.alarm_notifications.arn]
  ok_actions    = [aws_sns_topic.alarm_notifications.arn]

  tags = {
    Project     = var.project_name
    Environment = local.env
  }
}

# RDS Connections High
resource "aws_cloudwatch_metric_alarm" "rds_connections_high" {
  alarm_name          = "${local.prefix}-rds-connections-high"
  alarm_description   = "RDS connection count exceeds threshold"
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.alarm_rds_connections_threshold
  period              = 300
  evaluation_periods  = 2
  statistic           = "Average"
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }
  alarm_actions = [aws_sns_topic.alarm_notifications.arn]
  ok_actions    = [aws_sns_topic.alarm_notifications.arn]

  tags = {
    Project     = var.project_name
    Environment = local.env
  }
}

# Lambda Errors
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${local.prefix}-lambda-errors"
  alarm_description   = "Lambda error count exceeds threshold"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.alarm_lambda_errors_threshold
  period              = 300
  evaluation_periods  = 1
  statistic           = "Sum"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarm_notifications.arn]
  ok_actions          = [aws_sns_topic.alarm_notifications.arn]

  tags = {
    Project     = var.project_name
    Environment = local.env
  }
}

# Lambda Throttles
resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${local.prefix}-lambda-throttles"
  alarm_description   = "Lambda throttle count exceeds threshold"
  namespace           = "AWS/Lambda"
  metric_name         = "Throttles"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  period              = 300
  evaluation_periods  = 1
  statistic           = "Sum"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarm_notifications.arn]
  ok_actions          = [aws_sns_topic.alarm_notifications.arn]

  tags = {
    Project     = var.project_name
    Environment = local.env
  }
}

# Lambda Duration High
resource "aws_cloudwatch_metric_alarm" "lambda_duration_high" {
  alarm_name          = "${local.prefix}-lambda-duration-high"
  alarm_description   = "Lambda duration exceeds threshold"
  namespace           = "AWS/Lambda"
  metric_name         = "Duration"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.alarm_lambda_duration_threshold
  period              = 300
  evaluation_periods  = 2
  statistic           = "Average"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarm_notifications.arn]
  ok_actions          = [aws_sns_topic.alarm_notifications.arn]

  tags = {
    Project     = var.project_name
    Environment = local.env
  }
}

# SQS DLQ Messages
resource "aws_cloudwatch_metric_alarm" "sqs_dlq_messages" {
  alarm_name          = "${local.prefix}-sqs-dlq-messages"
  alarm_description   = "SQS DLQ has visible messages"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  period              = 300
  evaluation_periods  = 1
  statistic           = "Sum"
  dimensions = {
    QueueName = aws_sqs_queue.task_events_dlq.name
  }
  alarm_actions = [aws_sns_topic.alarm_notifications.arn]
  ok_actions    = [aws_sns_topic.alarm_notifications.arn]

  tags = {
    Project     = var.project_name
    Environment = local.env
  }
}
