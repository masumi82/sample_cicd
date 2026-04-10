# --- v13: GuardDuty (conditional) ---

resource "aws_guardduty_detector" "main" {
  count  = var.enable_guardduty ? 1 : 0
  enable = true

  tags = {
    Name        = "${local.prefix}-guardduty"
    Project     = var.project_name
    Environment = local.env
  }
}

# EventBridge rule on DEFAULT bus — GuardDuty findings (severity >= MEDIUM)
resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  count       = var.enable_guardduty ? 1 : 0
  name        = "${local.prefix}-guardduty-findings"
  description = "Route GuardDuty findings (MEDIUM+) to SNS"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{
        numeric = [">=", 4]
      }]
    }
  })

  tags = {
    Project     = var.project_name
    Environment = local.env
  }
}

resource "aws_cloudwatch_event_target" "guardduty_to_sns" {
  count     = var.enable_guardduty ? 1 : 0
  rule      = aws_cloudwatch_event_rule.guardduty_findings[0].name
  target_id = "guardduty-to-sns"
  arn       = aws_sns_topic.alarm_notifications.arn
}
