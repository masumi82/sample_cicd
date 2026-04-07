# --- v6: SNS Alarm Notification Topic ---

resource "aws_sns_topic" "alarm_notifications" {
  name = "${local.prefix}-alarm-notifications"

  tags = {
    Name        = "${local.prefix}-alarm-notifications"
    Project     = var.project_name
    Environment = local.env
  }
}

# Conditional email subscription (created only when alarm_email is set)
resource "aws_sns_topic_subscription" "alarm_email" {
  count     = var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alarm_notifications.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}
