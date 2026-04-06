# Terraform リソース設計書 (v6)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-06 |
| バージョン | 6.0 |
| 前バージョン | [infrastructure_v5.md](infrastructure_v5.md) (v5.0) |

## 変更概要

v5 の 71 アクティブリソースに以下を追加する:

- **新規ファイル**: `monitoring.tf`, `sns.tf`, `webui.tf`
- **変更ファイル**: `variables.tf`（v6 変数追加）、`outputs.tf`（Dashboard / SNS / Web UI 出力追加）、`dev.tfvars`（v6 パラメータ追加）、`prod.tfvars`（v6 パラメータ追加）、`iam.tf`（X-Ray 権限追加）、`ecs.tf`（X-Ray サイドカー + 環境変数追加）、`logs.tf`（X-Ray ロググループ追加）、`lambda.tf`（X-Ray Active Tracing 有効化）
- **追加リソース数**: 20 リソース
- **主要機能**: CloudWatch 監視ダッシュボード + アラーム、SNS 通知、Web UI 配信基盤、X-Ray 分散トレーシング

デプロイ後のアクティブリソース: 71 + 20 = **91 リソース**（dev 環境）

## 1. Terraform リソース一覧

### v5 から継続（71 リソース）

（v5 の一覧と同一。詳細は [infrastructure_v5.md](infrastructure_v5.md) を参照）

> **重要変更**: ECS タスク定義に X-Ray サイドカーコンテナが追加される。
> Lambda 3 関数に Active Tracing が有効化される。
> IAM ロールに X-Ray 権限が追加される。

### v6 新規（20 リソース）

#### monitoring.tf（13 リソース）

| # | リソースタイプ | リソース名 | 用途 |
|---|--------------|-----------|------|
| 72 | `aws_cloudwatch_dashboard` | `main` | 統合監視ダッシュボード（ALB / ECS / RDS / Lambda / SQS） |
| 73 | `aws_cloudwatch_metric_alarm` | `alb_5xx` | ALB 5xx エラー数アラーム |
| 74 | `aws_cloudwatch_metric_alarm` | `alb_unhealthy_hosts` | ALB Unhealthy Host 数アラーム |
| 75 | `aws_cloudwatch_metric_alarm` | `alb_high_latency` | ALB レスポンス時間アラーム |
| 76 | `aws_cloudwatch_metric_alarm` | `ecs_cpu_high` | ECS CPU 使用率アラーム |
| 77 | `aws_cloudwatch_metric_alarm` | `ecs_memory_high` | ECS メモリ使用率アラーム |
| 78 | `aws_cloudwatch_metric_alarm` | `rds_cpu_high` | RDS CPU 使用率アラーム |
| 79 | `aws_cloudwatch_metric_alarm` | `rds_free_storage_low` | RDS 空きストレージアラーム |
| 80 | `aws_cloudwatch_metric_alarm` | `rds_connections_high` | RDS 接続数アラーム |
| 81 | `aws_cloudwatch_metric_alarm` | `lambda_errors` | Lambda エラー数アラーム |
| 82 | `aws_cloudwatch_metric_alarm` | `lambda_throttles` | Lambda スロットル数アラーム |
| 83 | `aws_cloudwatch_metric_alarm` | `lambda_duration_high` | Lambda 実行時間アラーム |
| 84 | `aws_cloudwatch_metric_alarm` | `sqs_dlq_messages` | SQS DLQ 滞留メッセージアラーム |

#### sns.tf（2 リソース）

| # | リソースタイプ | リソース名 | 用途 |
|---|--------------|-----------|------|
| 85 | `aws_sns_topic` | `alarm_notifications` | アラーム通知 SNS トピック |
| 86 | `aws_sns_topic_subscription` | `alarm_email` | メール通知サブスクリプション（条件付き） |

#### webui.tf（4 リソース）

| # | リソースタイプ | リソース名 | 用途 |
|---|--------------|-----------|------|
| 87 | `aws_s3_bucket` | `webui` | Web UI 静的ファイルストレージ |
| 88 | `aws_s3_bucket_public_access_block` | `webui` | パブリックアクセス全ブロック |
| 89 | `aws_cloudfront_origin_access_control` | `webui` | CloudFront → S3 OAC 認証 |
| 90 | `aws_cloudfront_distribution` | `webui` | Web UI CDN ディストリビューション |

#### logs.tf（1 リソース）

| # | リソースタイプ | リソース名 | 用途 |
|---|--------------|-----------|------|
| 91 | `aws_cloudwatch_log_group` | `xray` | X-Ray デーモンサイドカー用ロググループ |

> **既存リソース変更（リソース数に含めない）:**
> - `aws_iam_role_policy.ecs_task_events` に X-Ray 権限（`xray:PutTraceSegments`, `xray:PutTelemetryRecords`, `xray:GetSamplingRules`, `xray:GetSamplingTargets`）を追加
> - `aws_iam_role_policy.lambda_task_created` / `lambda_task_completed` / `lambda_task_cleanup` に同じ X-Ray 権限を追加
> - `aws_ecs_task_definition.app` に X-Ray デーモンサイドカーコンテナ + `ENABLE_XRAY` / `CORS_ALLOWED_ORIGINS` 環境変数を追加
> - `aws_lambda_function` 3 関数に `tracing_config { mode = "Active" }` を追加

## 2. ファイル構成

```
infra/
├── main.tf              [変更なし]
├── alb.tf               [変更なし]
├── ecr.tf               [変更なし]
├── ecs.tf               [変更: X-Ray サイドカー + ENABLE_XRAY / CORS_ALLOWED_ORIGINS 環境変数追加]
├── iam.tf               [変更: ECS タスクロール + Lambda 3 ロールに X-Ray 権限追加]
├── security_groups.tf   [変更なし]
├── logs.tf              [変更: X-Ray デーモン用ロググループ追加]
├── rds.tf               [変更なし]
├── secrets.tf           [変更なし]
├── autoscaling.tf       [変更なし]
├── https.tf             [変更なし]
├── sqs.tf               [変更なし]
├── lambda.tf            [変更: 3 関数に tracing_config { mode = "Active" } 追加]
├── eventbridge.tf       [変更なし]
├── vpc_endpoints.tf     [変更なし]
├── s3.tf                [変更なし]
├── cloudfront.tf        [変更なし]
├── monitoring.tf        [新規: CloudWatch Dashboard + 12 Alarms]
├── sns.tf               [新規: SNS Topic + 条件付き Email Subscription]
├── webui.tf             [新規: Web UI S3 + CloudFront]
├── variables.tf         [変更: v6 変数追加]
├── outputs.tf           [変更: Dashboard / SNS / Web UI 出力追加]
├── dev.tfvars           [変更: v6 パラメータ追加]
└── prod.tfvars          [変更: v6 パラメータ追加]
```

## 3. 新規リソース詳細設計

### 3.1 monitoring.tf

#### 3.1.1 CloudWatch Dashboard

```hcl
aws_cloudwatch_dashboard "main":
  dashboard_name = "${local.prefix}-dashboard"
  dashboard_body = jsonencode({
    widgets = [
      # Row 1: ALB メトリクス
      {
        type   = "metric"
        x = 0, y = 0, width = 12, height = 6
        properties = {
          title   = "ALB Request Count & 5xx Errors"
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.main.arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", aws_lb.main.arn_suffix]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
        }
      },
      {
        type   = "metric"
        x = 12, y = 0, width = 12, height = 6
        properties = {
          title   = "ALB Response Time & Healthy Hosts"
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.main.arn_suffix, { stat = "Average" }],
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", aws_lb_target_group.app.arn_suffix,
             "LoadBalancer", aws_lb.main.arn_suffix, { stat = "Average" }]
          ]
          period = 300
          region = var.aws_region
        }
      },

      # Row 2: ECS メトリクス
      {
        type   = "metric"
        x = 0, y = 6, width = 12, height = 6
        properties = {
          title   = "ECS CPU Utilization"
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.main.name,
             "ServiceName", aws_ecs_service.app.name]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
        }
      },
      {
        type   = "metric"
        x = 12, y = 6, width = 12, height = 6
        properties = {
          title   = "ECS Memory Utilization"
          metrics = [
            ["AWS/ECS", "MemoryUtilization", "ClusterName", aws_ecs_cluster.main.name,
             "ServiceName", aws_ecs_service.app.name]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
        }
      },

      # Row 3: RDS メトリクス
      {
        type   = "metric"
        x = 0, y = 12, width = 8, height = 6
        properties = {
          title   = "RDS CPU Utilization"
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.main.identifier]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
        }
      },
      {
        type   = "metric"
        x = 8, y = 12, width = 8, height = 6
        properties = {
          title   = "RDS Free Storage Space"
          metrics = [
            ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", aws_db_instance.main.identifier]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
        }
      },
      {
        type   = "metric"
        x = 16, y = 12, width = 8, height = 6
        properties = {
          title   = "RDS Database Connections"
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", aws_db_instance.main.identifier]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
        }
      },

      # Row 4: Lambda メトリクス
      {
        type   = "metric"
        x = 0, y = 18, width = 12, height = 6
        properties = {
          title   = "Lambda Errors"
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.task_created_handler.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.task_completed_handler.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.task_cleanup_handler.function_name]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
        }
      },
      {
        type   = "metric"
        x = 12, y = 18, width = 12, height = 6
        properties = {
          title   = "Lambda Duration"
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.task_created_handler.function_name],
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.task_completed_handler.function_name],
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.task_cleanup_handler.function_name]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
        }
      },

      # Row 5: SQS メトリクス
      {
        type   = "metric"
        x = 0, y = 24, width = 12, height = 6
        properties = {
          title   = "SQS Messages (Main Queue)"
          metrics = [
            ["AWS/SQS", "NumberOfMessagesSent", "QueueName", aws_sqs_queue.task_events.name],
            ["AWS/SQS", "NumberOfMessagesReceived", "QueueName", aws_sqs_queue.task_events.name],
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.task_events.name]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
        }
      },
      {
        type   = "metric"
        x = 12, y = 24, width = 12, height = 6
        properties = {
          title   = "SQS DLQ Messages"
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.task_events_dlq.name]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
        }
      }
    ]
  })
```

> **設計判断 - ダッシュボード構成:**
> 5 行構成で ALB → ECS → RDS → Lambda → SQS の順にリクエストフローに沿って配置。
> 障害発生時にダッシュボードを上から順に見ることで、ボトルネックの特定が容易になる。

#### 3.1.2 CloudWatch Alarms（12 件）

全アラームは SNS トピック `aws_sns_topic.alarm_notifications` に通知する。

```hcl
# ALB 5xx エラー
aws_cloudwatch_metric_alarm "alb_5xx":
  alarm_name          = "${local.prefix}-alb-5xx"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.alarm_alb_5xx_threshold
  period              = 60
  evaluation_periods  = 3
  statistic           = "Sum"
  dimensions          = { LoadBalancer = aws_lb.main.arn_suffix }
  alarm_actions       = [aws_sns_topic.alarm_notifications.arn]
  ok_actions          = [aws_sns_topic.alarm_notifications.arn]
  tags                = { Project = var.project_name, Environment = local.env }

# ALB Unhealthy Hosts
aws_cloudwatch_metric_alarm "alb_unhealthy_hosts":
  alarm_name          = "${local.prefix}-alb-unhealthy-hosts"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  period              = 60
  evaluation_periods  = 2
  statistic           = "Average"
  dimensions          = {
    TargetGroup  = aws_lb_target_group.app.arn_suffix
    LoadBalancer = aws_lb.main.arn_suffix
  }
  alarm_actions       = [aws_sns_topic.alarm_notifications.arn]
  ok_actions          = [aws_sns_topic.alarm_notifications.arn]

# ALB High Latency
aws_cloudwatch_metric_alarm "alb_high_latency":
  alarm_name          = "${local.prefix}-alb-high-latency"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.alarm_alb_latency_threshold
  period              = 60
  evaluation_periods  = 3
  statistic           = "Average"
  dimensions          = { LoadBalancer = aws_lb.main.arn_suffix }
  alarm_actions       = [aws_sns_topic.alarm_notifications.arn]
  ok_actions          = [aws_sns_topic.alarm_notifications.arn]

# ECS CPU High
aws_cloudwatch_metric_alarm "ecs_cpu_high":
  alarm_name          = "${local.prefix}-ecs-cpu-high"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.alarm_ecs_cpu_threshold
  period              = 300
  evaluation_periods  = 2
  statistic           = "Average"
  dimensions          = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.app.name
  }
  alarm_actions       = [aws_sns_topic.alarm_notifications.arn]
  ok_actions          = [aws_sns_topic.alarm_notifications.arn]

# ECS Memory High
aws_cloudwatch_metric_alarm "ecs_memory_high":
  alarm_name          = "${local.prefix}-ecs-memory-high"
  namespace           = "AWS/ECS"
  metric_name         = "MemoryUtilization"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.alarm_ecs_memory_threshold
  period              = 300
  evaluation_periods  = 2
  statistic           = "Average"
  dimensions          = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.app.name
  }
  alarm_actions       = [aws_sns_topic.alarm_notifications.arn]
  ok_actions          = [aws_sns_topic.alarm_notifications.arn]

# RDS CPU High
aws_cloudwatch_metric_alarm "rds_cpu_high":
  alarm_name          = "${local.prefix}-rds-cpu-high"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.alarm_rds_cpu_threshold
  period              = 300
  evaluation_periods  = 2
  statistic           = "Average"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.main.identifier }
  alarm_actions       = [aws_sns_topic.alarm_notifications.arn]
  ok_actions          = [aws_sns_topic.alarm_notifications.arn]

# RDS Free Storage Low
aws_cloudwatch_metric_alarm "rds_free_storage_low":
  alarm_name          = "${local.prefix}-rds-free-storage-low"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  comparison_operator = "LessThanOrEqualToThreshold"
  threshold           = var.alarm_rds_free_storage_threshold
  period              = 300
  evaluation_periods  = 1
  statistic           = "Average"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.main.identifier }
  alarm_actions       = [aws_sns_topic.alarm_notifications.arn]
  ok_actions          = [aws_sns_topic.alarm_notifications.arn]

# RDS Connections High
aws_cloudwatch_metric_alarm "rds_connections_high":
  alarm_name          = "${local.prefix}-rds-connections-high"
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.alarm_rds_connections_threshold
  period              = 300
  evaluation_periods  = 2
  statistic           = "Average"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.main.identifier }
  alarm_actions       = [aws_sns_topic.alarm_notifications.arn]
  ok_actions          = [aws_sns_topic.alarm_notifications.arn]

# Lambda Errors (全関数合算)
aws_cloudwatch_metric_alarm "lambda_errors":
  alarm_name          = "${local.prefix}-lambda-errors"
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

# Lambda Throttles
aws_cloudwatch_metric_alarm "lambda_throttles":
  alarm_name          = "${local.prefix}-lambda-throttles"
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

# Lambda Duration High
aws_cloudwatch_metric_alarm "lambda_duration_high":
  alarm_name          = "${local.prefix}-lambda-duration-high"
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

# SQS DLQ Messages
aws_cloudwatch_metric_alarm "sqs_dlq_messages":
  alarm_name          = "${local.prefix}-sqs-dlq-messages"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  period              = 300
  evaluation_periods  = 1
  statistic           = "Sum"
  dimensions          = { QueueName = aws_sqs_queue.task_events_dlq.name }
  alarm_actions       = [aws_sns_topic.alarm_notifications.arn]
  ok_actions          = [aws_sns_topic.alarm_notifications.arn]
```

> **設計判断 - `ok_actions` の設定:**
> 全アラームに `ok_actions` を設定し、復旧時にも通知を送信する。
> これにより障害の発生〜解消までのライフサイクルを追跡できる。

> **設計判断 - `treat_missing_data = "notBreaching"` (Lambda アラーム):**
> Lambda はイベント駆動のため、呼び出しがない期間はメトリクスが送信されない。
> 欠損データを「正常」として扱い、誤検知を防止する。

#### 3.1.3 アラーム閾値一覧

| アラーム | メトリクス | 比較演算子 | dev 閾値 | prod 閾値 | 評価期間 | 評価回数 |
|---------|----------|----------|---------|----------|---------|---------|
| `alb-5xx` | HTTPCode_Target_5XX_Count | >= | 10 | 5 | 60s | 3 |
| `alb-unhealthy-hosts` | UnHealthyHostCount | >= | 1 | 1 | 60s | 2 |
| `alb-high-latency` | TargetResponseTime (avg) | >= | 3.0s | 1.0s | 60s | 3 |
| `ecs-cpu-high` | CPUUtilization (avg) | >= | 90% | 80% | 300s | 2 |
| `ecs-memory-high` | MemoryUtilization (avg) | >= | 90% | 80% | 300s | 2 |
| `rds-cpu-high` | CPUUtilization (avg) | >= | 90% | 80% | 300s | 2 |
| `rds-free-storage-low` | FreeStorageSpace | <= | 2GB | 5GB | 300s | 1 |
| `rds-connections-high` | DatabaseConnections | >= | 50 | 100 | 300s | 2 |
| `lambda-errors` | Errors (sum) | >= | 5 | 3 | 300s | 1 |
| `lambda-throttles` | Throttles (sum) | >= | 1 | 1 | 300s | 1 |
| `lambda-duration-high` | Duration (avg) | >= | 10000ms | 5000ms | 300s | 2 |
| `sqs-dlq-messages` | ApproximateNumberOfMessagesVisible | >= | 1 | 1 | 300s | 1 |

> **設計判断 - dev と prod の閾値差:**
> dev 環境では誤検知を減らすために閾値を緩和する（例: ALB 5xx は 10 回 / ECS CPU は 90%）。
> prod 環境では早期検知のために厳格な閾値を設定する（例: ALB 5xx は 5 回 / ECS CPU は 80%）。
> 閾値はすべて変数化されており、`dev.tfvars` / `prod.tfvars` で環境ごとに調整可能。

### 3.2 sns.tf

```hcl
# アラーム通知 SNS トピック
aws_sns_topic "alarm_notifications":
  name = "${local.prefix}-alarm-notifications"
  tags = { Project = var.project_name, Environment = local.env }

# 条件付きメール通知サブスクリプション
aws_sns_topic_subscription "alarm_email":
  count     = var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alarm_notifications.arn
  protocol  = "email"
  endpoint  = var.alarm_email
```

> **設計判断 - 条件付きサブスクリプション:**
> `alarm_email` が空文字の場合はサブスクリプションを作成しない（`count = 0`）。
> SNS トピック自体は常に作成し、アラームの `alarm_actions` から参照できる状態にする。
> メールアドレスを設定すると AWS からの確認メールを承認する手動操作が必要になる。

### 3.3 webui.tf

```hcl
# Web UI S3 バケット
aws_s3_bucket "webui":
  bucket = "${local.prefix}-webui"
  tags   = { Project = var.project_name, Environment = local.env }

# パブリックアクセス全ブロック
aws_s3_bucket_public_access_block "webui":
  bucket                  = aws_s3_bucket.webui.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

# CloudFront OAC
aws_cloudfront_origin_access_control "webui":
  name                              = "${local.prefix}-webui-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"

# CloudFront ディストリビューション
aws_cloudfront_distribution "webui":
  enabled             = true
  default_root_object = "index.html"
  price_class         = var.cloudfront_price_class
  comment             = "${local.prefix} webui CDN"

  origin {
    domain_name              = aws_s3_bucket.webui.bucket_regional_domain_name
    origin_id                = "s3-webui"
    origin_access_control_id = aws_cloudfront_origin_access_control.webui.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-webui"
    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id
  }

  # SPA ルーティング対応: 403/404 を index.html にフォールバック
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = { Project = var.project_name, Environment = local.env }
```

> **設計判断 - SPA ルーティング（`custom_error_response`）:**
> React SPA はクライアントサイドルーティングを使用するため、`/tasks/123` のようなパスへの直接アクセスは
> S3 上にファイルが存在せず 403/404 を返す。`custom_error_response` で `index.html` にフォールバックし、
> React Router がクライアント側でルーティングを処理する。

> **設計判断 - `data.aws_cloudfront_cache_policy.caching_optimized` の再利用:**
> v5 の `cloudfront.tf` で定義済みの `data` ソースをそのまま参照する。
> 同じマネージドポリシーを使うため、新規 `data` ソースの追加は不要。

> **設計判断 - `default_root_object = "index.html"`:**
> ルートパス（`/`）へのアクセス時に `index.html` を返す。添付ファイル用の
> CloudFront（v5）では空文字だが、Web UI 用には SPA のエントリポイントとして必須。

### 3.4 logs.tf（追加分）

```hcl
# X-Ray デーモンサイドカー用ロググループ
aws_cloudwatch_log_group "xray":
  name              = "/ecs/${local.prefix}-xray"
  retention_in_days = var.log_retention_days
  tags              = { Name = "${local.prefix}-xray-logs", Project = var.project_name, Environment = local.env }
```

## 4. 既存ファイル変更詳細

### 4.1 iam.tf（X-Ray 権限追加）

```hcl
# ECS タスクロールに X-Ray 権限を追加
# aws_iam_role_policy.ecs_task_events の Statement に追記
{
  Effect = "Allow"
  Action = [
    "xray:PutTraceSegments",
    "xray:PutTelemetryRecords",
    "xray:GetSamplingRules",
    "xray:GetSamplingTargets"
  ]
  Resource = "*"
}

# Lambda 3 ロールに同じ X-Ray 権限を追加
# aws_iam_role_policy.lambda_task_created の Statement に追記
# aws_iam_role_policy.lambda_task_completed の Statement に追記
# aws_iam_role_policy.lambda_task_cleanup の Statement に追記
{
  Effect = "Allow"
  Action = [
    "xray:PutTraceSegments",
    "xray:PutTelemetryRecords",
    "xray:GetSamplingRules",
    "xray:GetSamplingTargets"
  ]
  Resource = "*"
}
```

> **設計判断 - X-Ray 権限の `Resource = "*"`:**
> X-Ray API はリソースレベルの権限制御をサポートしていないため、`Resource = "*"` が必須。
> AWS 公式ドキュメントの推奨設定に従う。

### 4.2 ecs.tf（X-Ray サイドカー + 環境変数追加）

```hcl
# aws_ecs_task_definition.app の container_definitions に X-Ray デーモンを追加
container_definitions = jsonencode([
  {
    name      = "app"
    image     = "${aws_ecr_repository.app.repository_url}:latest"
    essential = true
    ...既存の設定,

    environment = [
      ...既存の環境変数,
      {
        name  = "ENABLE_XRAY"
        value = "true"
      },
      {
        name  = "CORS_ALLOWED_ORIGINS"
        value = "https://${aws_cloudfront_distribution.webui.domain_name}"
      }
    ]
  },
  {
    name      = "xray-daemon"
    image     = "amazon/aws-xray-daemon:latest"
    essential = false

    portMappings = [
      {
        containerPort = 2000
        protocol      = "udp"
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.xray.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "xray"
      }
    }
  }
])
```

> **設計判断 - X-Ray デーモンのサイドカーパターン:**
> X-Ray SDK はトレースデータを UDP 2000 番ポートでローカルのデーモンに送信する。
> ECS Fargate ではサイドカーコンテナとしてデーモンを配置し、`awsvpc` ネットワークモードにより
> 同一タスク内のコンテナ間で `localhost:2000` で通信可能。

> **設計判断 - `essential = false`:**
> X-Ray デーモンが停止してもアプリケーションコンテナは稼働し続ける。
> 監視系コンポーネントの障害がサービス可用性に影響しないようにする。

> **設計判断 - CPU/Memory の増加:**
> X-Ray デーモンサイドカーの追加により、タスク全体のリソース使用量が増加する。
> dev 環境: 256 CPU / 512 MB → 512 CPU / 1024 MB に変更。
> prod 環境: 512 CPU / 1024 MB → 既に十分な割り当てだが、必要に応じて増加。

> **設計判断 - `CORS_ALLOWED_ORIGINS` 環境変数:**
> Web UI の CloudFront ドメインを CORS 許可オリジンとして設定する。
> dev 環境では `*`（全オリジン許可）も検討可能だが、CloudFront ドメインを明示設定することで
> 本番に近い構成を学習用途でも維持する。

### 4.3 lambda.tf（X-Ray Active Tracing 有効化）

```hcl
# 3 関数すべてに tracing_config ブロックを追加
resource "aws_lambda_function" "task_created_handler" {
  ...既存の設定

  tracing_config {
    mode = "Active"
  }
}

resource "aws_lambda_function" "task_completed_handler" {
  ...既存の設定

  tracing_config {
    mode = "Active"
  }
}

resource "aws_lambda_function" "task_cleanup_handler" {
  ...既存の設定

  tracing_config {
    mode = "Active"
  }
}
```

> **設計判断 - Active Tracing モード:**
> `Active` モードでは Lambda サービスが X-Ray にサンプリングされたリクエストのトレースを送信する。
> `PassThrough` モード（デフォルト）と異なり、上流からのトレースヘッダーがなくても
> Lambda 自身がトレースを開始する。ECS → SQS → Lambda のエンドツーエンドトレースが可能になる。

### 4.4 outputs.tf（v6 出力追加）

```hcl
output "dashboard_url" {
  description = "URL of the CloudWatch Dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "sns_topic_arn" {
  description = "ARN of the alarm notification SNS topic"
  value       = aws_sns_topic.alarm_notifications.arn
}

output "webui_bucket_name" {
  description = "Name of the Web UI S3 bucket"
  value       = aws_s3_bucket.webui.bucket
}

output "webui_cloudfront_domain_name" {
  description = "Domain name of the Web UI CloudFront distribution"
  value       = aws_cloudfront_distribution.webui.domain_name
}

output "webui_cloudfront_distribution_id" {
  description = "ID of the Web UI CloudFront distribution"
  value       = aws_cloudfront_distribution.webui.id
}
```

## 5. 変数設計（variables.tf 変更）

### v6 追加変数

| 変数名 | 型 | デフォルト値 | 説明 |
|--------|----|-------------|------|
| `alarm_email` | string | `""` | アラーム通知先メールアドレス（空の場合はサブスクリプション未作成） |
| `alarm_alb_5xx_threshold` | number | `10` | ALB 5xx エラー数の閾値 |
| `alarm_alb_latency_threshold` | number | `3.0` | ALB レスポンス時間の閾値（秒） |
| `alarm_ecs_cpu_threshold` | number | `90` | ECS CPU 使用率の閾値（%） |
| `alarm_ecs_memory_threshold` | number | `90` | ECS メモリ使用率の閾値（%） |
| `alarm_rds_cpu_threshold` | number | `90` | RDS CPU 使用率の閾値（%） |
| `alarm_rds_free_storage_threshold` | number | `2000000000` | RDS 空きストレージの閾値（バイト、デフォルト 2GB） |
| `alarm_rds_connections_threshold` | number | `50` | RDS 接続数の閾値 |
| `alarm_lambda_errors_threshold` | number | `5` | Lambda エラー数の閾値 |
| `alarm_lambda_duration_threshold` | number | `10000` | Lambda 実行時間の閾値（ミリ秒） |

### 環境別パラメータ（dev.tfvars / prod.tfvars に追加）

| 変数名 | dev.tfvars | prod.tfvars |
|--------|-----------|-------------|
| `alarm_email` | `""` | `""` |
| `alarm_alb_5xx_threshold` | `10` | `5` |
| `alarm_alb_latency_threshold` | `3.0` | `1.0` |
| `alarm_ecs_cpu_threshold` | `90` | `80` |
| `alarm_ecs_memory_threshold` | `90` | `80` |
| `alarm_rds_cpu_threshold` | `90` | `80` |
| `alarm_rds_free_storage_threshold` | `2000000000` | `5000000000` |
| `alarm_rds_connections_threshold` | `50` | `100` |
| `alarm_lambda_errors_threshold` | `5` | `3` |
| `alarm_lambda_duration_threshold` | `10000` | `5000` |
| `fargate_cpu` | `512` | `512` |
| `fargate_memory` | `1024` | `1024` |

> **注意**: `fargate_cpu` / `fargate_memory` は X-Ray サイドカー追加に伴い dev 環境で増加
> （256/512 → 512/1024）。prod 環境は変更なし（既に 512/1024）。

## 6. リソース依存関係（v6 追加分）

```
# SNS → Monitoring フロー
aws_sns_topic.alarm_notifications
  └──▶ aws_sns_topic_subscription.alarm_email (count = alarm_email != "" ? 1 : 0)
  └──▶ aws_cloudwatch_metric_alarm.alb_5xx (alarm_actions)
  └──▶ aws_cloudwatch_metric_alarm.alb_unhealthy_hosts (alarm_actions)
  └──▶ aws_cloudwatch_metric_alarm.alb_high_latency (alarm_actions)
  └──▶ aws_cloudwatch_metric_alarm.ecs_cpu_high (alarm_actions)
  └──▶ aws_cloudwatch_metric_alarm.ecs_memory_high (alarm_actions)
  └──▶ aws_cloudwatch_metric_alarm.rds_cpu_high (alarm_actions)
  └──▶ aws_cloudwatch_metric_alarm.rds_free_storage_low (alarm_actions)
  └──▶ aws_cloudwatch_metric_alarm.rds_connections_high (alarm_actions)
  └──▶ aws_cloudwatch_metric_alarm.lambda_errors (alarm_actions)
  └──▶ aws_cloudwatch_metric_alarm.lambda_throttles (alarm_actions)
  └──▶ aws_cloudwatch_metric_alarm.lambda_duration_high (alarm_actions)
  └──▶ aws_cloudwatch_metric_alarm.sqs_dlq_messages (alarm_actions)

# Dashboard → 既存リソース参照
aws_cloudwatch_dashboard.main
  ├──▶ aws_lb.main (ALB メトリクス)
  ├──▶ aws_lb_target_group.app (TargetGroup メトリクス)
  ├──▶ aws_ecs_cluster.main + aws_ecs_service.app (ECS メトリクス)
  ├──▶ aws_db_instance.main (RDS メトリクス)
  ├──▶ aws_lambda_function.* (Lambda メトリクス)
  └──▶ aws_sqs_queue.task_events + task_events_dlq (SQS メトリクス)

# Web UI S3 + CloudFront フロー
aws_s3_bucket.webui
  └──▶ aws_s3_bucket_public_access_block.webui
  └──▶ aws_cloudfront_origin_access_control.webui
         └──▶ aws_cloudfront_distribution.webui
                └──▶ aws_ecs_task_definition.app (CORS_ALLOWED_ORIGINS 環境変数)

# X-Ray フロー
aws_cloudwatch_log_group.xray
  └──▶ aws_ecs_task_definition.app (xray-daemon サイドカーの logConfiguration)
```

## 7. State 管理（変更なし）

| 項目 | 値 |
|------|------|
| Backend | local |
| State file | `infra/terraform.tfstate.d/{workspace}/terraform.tfstate` |
| Workspace | `dev`（実デプロイ）、`prod`（tfvars のみ） |

## 8. リソース数サマリ

| カテゴリ | v5 | v6 追加 | v6 合計 |
|---------|---:|-------:|-------:|
| VPC / ネットワーク | 10 | 0 | 10 |
| ALB | 3 | 0 | 3 |
| ECR | 1 | 0 | 1 |
| ECS | 3 | 0 | 3 |
| IAM | 12 | 0 | 12 |
| Security Groups | 9 | 0 | 9 |
| CloudWatch Logs | 4 | 1 | 5 |
| RDS | 3 | 0 | 3 |
| Secrets Manager | 3 | 0 | 3 |
| Auto Scaling | 2 | 0 | 2 |
| HTTPS (conditional) | 0 | 0 | 0 |
| SQS | 4 | 0 | 4 |
| Lambda | 8 | 0 | 8 |
| EventBridge | 4 | 0 | 4 |
| VPC Endpoints | 2 | 0 | 2 |
| S3 (attachments) | 4 | 0 | 4 |
| CloudFront (attachments) | 3 | 0 | 3 |
| CloudWatch Dashboard | 0 | 1 | 1 |
| CloudWatch Alarms | 0 | 12 | 12 |
| SNS | 0 | 2 | 2 |
| S3 + CloudFront (Web UI) | 0 | 4 | 4 |
| **合計** | **71** | **20** | **91** |

> `data` ソース（`aws_cloudfront_cache_policy.caching_optimized`, `archive_file.*`）はリソース数に含めない。
> HTTPS リソース（`enable_https = false` のため `count = 0`）もリソース数に含めない。
> `aws_sns_topic_subscription.alarm_email` は `alarm_email` が空でも `count = 0` でリソース定義としてカウントする。
