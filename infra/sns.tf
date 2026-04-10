# --- v6: SNS Alarm Notification Topic ---

resource "aws_sns_topic" "alarm_notifications" {
  name = "${local.prefix}-alarm-notifications"

  tags = {
    Name        = "${local.prefix}-alarm-notifications"
    Project     = var.project_name
    Environment = local.env
  }
}

# --- v13: SNS Topic Policy (allow EventBridge, CloudWatch, Backup to publish) ---
resource "aws_sns_topic_policy" "alarm_notifications" {
  arn = aws_sns_topic.alarm_notifications.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "SecurityEventPublishPolicy"
    Statement = [
      {
        Sid       = "AllowEventBridgePublish"
        Effect    = "Allow"
        Principal = { Service = "events.amazonaws.com" }
        Action    = "sns:Publish"
        Resource  = aws_sns_topic.alarm_notifications.arn
      },
      {
        Sid       = "AllowCloudWatchAlarmsPublish"
        Effect    = "Allow"
        Principal = { Service = "cloudwatch.amazonaws.com" }
        Action    = "sns:Publish"
        Resource  = aws_sns_topic.alarm_notifications.arn
      },
      {
        Sid       = "AllowBackupPublish"
        Effect    = "Allow"
        Principal = { Service = "backup.amazonaws.com" }
        Action    = "sns:Publish"
        Resource  = aws_sns_topic.alarm_notifications.arn
      }
    ]
  })
}

# Conditional email subscription (created only when alarm_email is set)
resource "aws_sns_topic_subscription" "alarm_email" {
  count     = var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alarm_notifications.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}
