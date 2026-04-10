# --- v13: Security Hub (conditional, depends on Config) ---

resource "aws_securityhub_account" "main" {
  count = var.enable_securityhub ? 1 : 0

  depends_on = [aws_config_configuration_recorder_status.main]
}

# CIS AWS Foundations Benchmark
resource "aws_securityhub_standards_subscription" "cis" {
  count         = var.enable_securityhub ? 1 : 0
  standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/cis-aws-foundations-benchmark/v/1.4.0"

  depends_on = [aws_securityhub_account.main]
}

# AWS Foundational Security Best Practices
resource "aws_securityhub_standards_subscription" "fsbp" {
  count         = var.enable_securityhub ? 1 : 0
  standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/aws-foundational-security-best-practices/v/1.0.0"

  depends_on = [aws_securityhub_account.main]
}

# EventBridge rule on DEFAULT bus — Security Hub HIGH/CRITICAL findings
resource "aws_cloudwatch_event_rule" "securityhub_findings" {
  count       = var.enable_securityhub ? 1 : 0
  name        = "${local.prefix}-securityhub-findings"
  description = "Route Security Hub HIGH/CRITICAL findings to SNS"

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity = {
          Label = ["HIGH", "CRITICAL"]
        }
      }
    }
  })

  tags = {
    Project     = var.project_name
    Environment = local.env
  }
}

resource "aws_cloudwatch_event_target" "securityhub_to_sns" {
  count     = var.enable_securityhub ? 1 : 0
  rule      = aws_cloudwatch_event_rule.securityhub_findings[0].name
  target_id = "securityhub-to-sns"
  arn       = aws_sns_topic.alarm_notifications.arn
}
