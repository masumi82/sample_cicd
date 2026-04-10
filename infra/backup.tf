# --- v12: AWS Backup ---

# Backup Vault
resource "aws_backup_vault" "main" {
  name = "${local.prefix}-backup-vault"

  tags = {
    Name        = "${local.prefix}-backup-vault"
    Project     = var.project_name
    Environment = local.env
  }
}

# Backup Vault Notifications → existing SNS topic
resource "aws_backup_vault_notifications" "main" {
  backup_vault_name   = aws_backup_vault.main.name
  sns_topic_arn       = aws_sns_topic.alarm_notifications.arn
  backup_vault_events = ["BACKUP_JOB_COMPLETED", "BACKUP_JOB_FAILED"]
}

# Backup Plan (daily + weekly)
resource "aws_backup_plan" "main" {
  name = "${local.prefix}-backup-plan"

  # Daily backup — UTC 18:00 (JST 3:00), retain N days
  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 18 * * ? *)"

    lifecycle {
      delete_after = var.backup_retention_daily
    }
  }

  # Weekly backup — Sunday UTC 18:00, retain N days
  rule {
    rule_name         = "weekly-backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 18 ? * 1 *)"

    lifecycle {
      delete_after = var.backup_retention_weekly
    }
  }

  tags = {
    Project     = var.project_name
    Environment = local.env
  }
}

# Backup Selection — tag-based (Backup = true)
resource "aws_backup_selection" "rds" {
  iam_role_arn = aws_iam_role.backup.arn
  name         = "${local.prefix}-rds-selection"
  plan_id      = aws_backup_plan.main.id

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Backup"
    value = "true"
  }
}

# Backup IAM Role
resource "aws_iam_role" "backup" {
  name = "${local.prefix}-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${local.prefix}-backup-role"
  }
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "backup_restores" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}
