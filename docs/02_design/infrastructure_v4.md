# Terraform リソース設計書 (v4)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-06 |
| バージョン | 4.0 |
| 前バージョン | [infrastructure_v3.md](infrastructure_v3.md) (v3.0) |

## 変更概要

v3 の 35 アクティブリソースに以下を追加する:

- **新規ファイル**: `sqs.tf`, `lambda.tf`, `eventbridge.tf`, `vpc_endpoints.tf`
- **変更ファイル**: `iam.tf`（Lambda IAM ロール追加、ECS タスクロールにポリシー追加）、`ecs.tf`（環境変数追加）、`variables.tf`（v4 変数追加）、`logs.tf`（Lambda ロググループ追加）
- **追加リソース数**: 28 リソース

デプロイ後のアクティブリソース: 35 + 28 = **63 リソース**

## 1. Terraform リソース一覧

### v3 から継続（35 リソース）

（v3 の一覧と同一。詳細は [infrastructure_v3.md](infrastructure_v3.md) を参照）

### v4 新規（28 リソース）

#### sqs.tf（4 リソース）

| # | リソースタイプ | リソース名 | 用途 |
|---|--------------|-----------|------|
| 36 | `aws_sqs_queue` | `task_events_dlq` | Dead Letter Queue（失敗メッセージ退避） |
| 37 | `aws_sqs_queue` | `task_events` | タスク作成イベントキュー（DLQ 参照） |
| 38 | `aws_sqs_queue_policy` | `task_events` | ECS タスクロールからの SendMessage を許可 |
| 39 | `aws_lambda_event_source_mapping` | `task_created` | SQS → Lambda トリガー設定 |

#### lambda.tf（9 リソース）

| # | リソースタイプ | リソース名 | 用途 |
|---|--------------|-----------|------|
| 40 | `aws_lambda_function` | `task_created_handler` | SQS トリガー Lambda（VPC 外） |
| 41 | `aws_lambda_function` | `task_completed_handler` | EventBridge トリガー Lambda（VPC 外） |
| 42 | `aws_lambda_function` | `task_cleanup_handler` | Scheduler トリガー Lambda（VPC 内） |
| 43 | `aws_lambda_permission` | `task_completed_eventbridge` | EventBridge からの Lambda 実行許可 |
| 44 | `aws_lambda_permission` | `task_cleanup_scheduler` | Scheduler からの Lambda 実行許可 |
| 45 | `aws_security_group` | `lambda_cleanup` | cleanup Lambda 用 SG（RDS / VPC Endpoint へのアウトバウンド） |
| 46 | `aws_security_group_rule` | `lambda_cleanup_to_rds` | cleanup Lambda → RDS (:5432) アウトバウンド |
| 47 | `aws_security_group_rule` | `lambda_cleanup_to_vpce` | cleanup Lambda → VPC Endpoint (:443) アウトバウンド |
| 48 | `aws_security_group_rule` | `rds_from_lambda_cleanup` | RDS ← Lambda cleanup インバウンド（rds.tf の SG 参照） |

#### eventbridge.tf（4 リソース）

| # | リソースタイプ | リソース名 | 用途 |
|---|--------------|-----------|------|
| 49 | `aws_cloudwatch_event_bus` | `main` | カスタムイベントバス（`sample-cicd-bus`） |
| 50 | `aws_cloudwatch_event_rule` | `task_completed` | TaskCompleted イベントのルール定義 |
| 51 | `aws_cloudwatch_event_target` | `task_completed_lambda` | ルールのターゲット → task_completed_handler Lambda |
| 52 | `aws_scheduler_schedule` | `task_cleanup` | 毎日 0:00 JST の定期実行スケジュール |

#### vpc_endpoints.tf（5 リソース）

| # | リソースタイプ | リソース名 | 用途 |
|---|--------------|-----------|------|
| 53 | `aws_vpc_endpoint` | `secretsmanager` | Secrets Manager への Interface Endpoint |
| 54 | `aws_vpc_endpoint` | `logs` | CloudWatch Logs への Interface Endpoint |
| 55 | `aws_security_group` | `vpc_endpoint` | VPC Endpoint 用 SG |
| 56 | `aws_security_group_rule` | `vpce_from_lambda` | Lambda cleanup → VPC Endpoint インバウンド (:443) |
| 57 | `aws_security_group_rule` | `vpce_outbound` | VPC Endpoint アウトバウンド（全許可） |

#### iam.tf（6 リソース追加）

| # | リソースタイプ | リソース名 | 用途 |
|---|--------------|-----------|------|
| 58 | `aws_iam_role` | `lambda_task_created` | task_created_handler 実行ロール |
| 59 | `aws_iam_role` | `lambda_task_completed` | task_completed_handler 実行ロール |
| 60 | `aws_iam_role` | `lambda_task_cleanup` | task_cleanup_handler 実行ロール |
| 61 | `aws_iam_role_policy` | `lambda_task_created` | SQS 受信 + CloudWatch Logs 書き込み |
| 62 | `aws_iam_role_policy` | `lambda_task_completed` | CloudWatch Logs 書き込み |
| 63 | `aws_iam_role_policy` | `lambda_task_cleanup` | Secrets Manager 読み取り + CloudWatch Logs 書き込み + VPC ENI 操作 |

> **既存リソース変更（リソース数に含めない）:**
> - `aws_iam_role_policy.ecs_task` に SQS SendMessage / EventBridge PutEvents ポリシーを追加
> - `aws_ecs_task_definition.app` に `SQS_QUEUE_URL`, `EVENTBRIDGE_BUS_NAME` 環境変数を追加

## 2. ファイル構成

```
infra/
├── main.tf              [変更なし]
├── alb.tf               [変更なし]
├── ecr.tf               [変更なし]
├── ecs.tf               [変更: 環境変数 SQS_QUEUE_URL / EVENTBRIDGE_BUS_NAME 追加]
├── iam.tf               [変更: Lambda IAM ロール追加、ECS タスクロールにポリシー追加]
├── security_groups.tf   [変更なし（Lambda SG は lambda.tf / vpc_endpoints.tf で定義）]
├── logs.tf              [変更: Lambda ロググループ 3 つ追加]
├── rds.tf               [変更なし（v3 Multi-AZ 継続）]
├── secrets.tf           [変更なし]
├── autoscaling.tf       [変更なし]
├── https.tf             [変更なし]
├── sqs.tf               [新規: SQS キュー + DLQ + EventSourceMapping]
├── lambda.tf            [新規: Lambda 関数 3 つ + SG + Permission]
├── eventbridge.tf       [新規: カスタムバス + ルール + Scheduler]
├── vpc_endpoints.tf     [新規: Interface Endpoint 2 つ + SG]
├── variables.tf         [変更: v4 変数追加]
├── outputs.tf           [変更: Lambda ARN 出力追加]
└── terraform.tfvars     [変更なし（デフォルト値で対応）]
```

## 3. 新規リソース詳細設計

### 3.1 sqs.tf

```hcl
# Dead Letter Queue（リトライ上限到達後の退避先）
aws_sqs_queue "task_events_dlq":
  name                      = "sample-cicd-task-events-dlq"
  message_retention_seconds = 1209600  # 14日間保持
  tags = { Project = "sample-cicd" }

# メインキュー
aws_sqs_queue "task_events":
  name                       = "sample-cicd-task-events"
  visibility_timeout_seconds = 60      # Lambda タイムアウト (30秒) の 2倍
  message_retention_seconds  = 86400   # 1日間保持
  redrive_policy = {
    deadLetterTargetArn = aws_sqs_queue.task_events_dlq.arn
    maxReceiveCount     = 3            # 3回失敗でDLQへ
  }
  tags = { Project = "sample-cicd" }

# SQS → Lambda イベントソースマッピング
aws_lambda_event_source_mapping "task_created":
  event_source_arn = aws_sqs_queue.task_events.arn
  function_name    = aws_lambda_function.task_created_handler.arn
  batch_size       = 1     # 1メッセージずつ処理（学習用途）
  enabled          = true
```

> **設計判断 - `visibility_timeout` を Lambda タイムアウトの 2 倍に設定:**
> Lambda の処理中に他のコンシューマーがメッセージを受け取らないようにするための SQS ベストプラクティス。
> Lambda タイムアウト 30 秒 × 2 = 60 秒。

> **設計判断 - `batch_size = 1`:**
> 学習目的のため 1 メッセージずつ処理し、動作を確認しやすくする。
> 本番では 10〜100 に設定してスループットを向上させる。

### 3.2 lambda.tf

```hcl
# Lambda 関数のデプロイパッケージ（zip ファイル）
data "archive_file" "task_created_handler":
  type        = "zip"
  source_file = "${path.root}/../lambda/task_created_handler.py"
  output_path = "${path.root}/../lambda/task_created_handler.zip"

# task_created_handler
aws_lambda_function "task_created_handler":
  function_name = "sample-cicd-task-created-handler"
  role          = aws_iam_role.lambda_task_created.arn
  handler       = "task_created_handler.handler"
  runtime       = "python3.12"
  filename      = data.archive_file.task_created_handler.output_path
  source_code_hash = data.archive_file.task_created_handler.output_base64sha256
  timeout       = 30
  memory_size   = 128
  environment:
    AWS_DEFAULT_REGION = var.aws_region
  tags = { Project = "sample-cicd" }
  # VPC 設定なし（RDS アクセス不要）

# task_completed_handler（同様の構成）
aws_lambda_function "task_completed_handler":
  function_name = "sample-cicd-task-completed-handler"
  ...（task_created と同様）

# task_cleanup_handler（VPC 内配置）
aws_lambda_function "task_cleanup_handler":
  function_name = "sample-cicd-task-cleanup-handler"
  role          = aws_iam_role.lambda_task_cleanup.arn
  handler       = "task_cleanup_handler.handler"
  runtime       = "python3.12"
  timeout       = 60      # RDS接続を含むため長めに設定
  memory_size   = 256     # psycopg2 使用のため多めに確保
  vpc_config:
    subnet_ids         = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_group_ids = [aws_security_group.lambda_cleanup.id]
  environment:
    DB_SECRET_ARN = aws_secretsmanager_secret.db_credentials.arn
    AWS_DEFAULT_REGION = var.aws_region
  tags = { Project = "sample-cicd" }

# EventBridge → Lambda 実行許可
aws_lambda_permission "task_completed_eventbridge":
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.task_completed_handler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.task_completed.arn

# Scheduler → Lambda 実行許可
aws_lambda_permission "task_cleanup_scheduler":
  statement_id  = "AllowSchedulerInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.task_cleanup_handler.function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = aws_scheduler_schedule.task_cleanup.arn
```

> **設計判断 - `source_code_hash` の使用:**
> Lambda のコードが変更されたときのみ Terraform が `aws lambda update-function-code` を実行するよう、
> zip ファイルのハッシュを変更検出に使用する。

### 3.3 eventbridge.tf

```hcl
# カスタムイベントバス
aws_cloudwatch_event_bus "main":
  name = "sample-cicd-bus"
  tags = { Project = "sample-cicd" }

# TaskCompleted イベントのルール
aws_cloudwatch_event_rule "task_completed":
  name           = "sample-cicd-task-completed"
  event_bus_name = aws_cloudwatch_event_bus.main.name
  event_pattern = {
    "source": ["sample-cicd"],
    "detail-type": ["TaskCompleted"]
  }
  tags = { Project = "sample-cicd" }

# ルールのターゲット → Lambda
aws_cloudwatch_event_target "task_completed_lambda":
  rule           = aws_cloudwatch_event_rule.task_completed.name
  event_bus_name = aws_cloudwatch_event_bus.main.name
  target_id      = "task-completed-lambda"
  arn            = aws_lambda_function.task_completed_handler.arn

# 定期クリーンアップスケジュール
aws_scheduler_schedule "task_cleanup":
  name       = "sample-cicd-task-cleanup"
  group_name = "default"
  flexible_time_window = { mode = "OFF" }
  schedule_expression          = "cron(0 15 * * ? *)"  # 毎日 15:00 UTC = 0:00 JST
  schedule_expression_timezone = "Asia/Tokyo"
  target:
    arn      = aws_lambda_function.task_cleanup_handler.arn
    role_arn = aws_iam_role.scheduler_task_cleanup.arn
  tags = { Project = "sample-cicd" }
```

> **設計判断 - `aws_cloudwatch_event_bus` vs `aws_events_event_bus`:**
> Terraform では EventBridge カスタムバスは `aws_cloudwatch_event_bus` リソースで定義する（歴史的経緯）。
> AWS コンソール上では "EventBridge" として表示される。

> **設計判断 - `aws_scheduler_schedule` を使用:**
> 旧来の `aws_cloudwatch_event_rule` の rate/cron 式でも Lambda を定期実行できるが、
> `aws_scheduler_schedule`（EventBridge Scheduler）の方が柔軟な設定（タイムゾーン指定など）が可能。
> v4 の学習テーマとして新しい Scheduler を採用する。

### 3.4 vpc_endpoints.tf

```hcl
# VPC Endpoint 用セキュリティグループ
aws_security_group "vpc_endpoint":
  name        = "sample-cicd-vpce-sg"
  description = "Security group for VPC Endpoints used by Lambda"
  vpc_id      = aws_vpc.main.id
  # インバウンド: Lambda cleanup SG から :443
  # アウトバウンド: 全許可

# Secrets Manager Interface Endpoint
aws_vpc_endpoint "secretsmanager":
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true  # SDK のエンドポイントURLを自動解決
  tags = { Project = "sample-cicd" }

# CloudWatch Logs Interface Endpoint
aws_vpc_endpoint "logs":
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true
  tags = { Project = "sample-cicd" }
```

> **設計判断 - `private_dns_enabled = true`:**
> これにより、Lambda 関数内で `boto3.client("secretsmanager")` を通常通り呼び出すだけで、
> 自動的に VPC Endpoint 経由のプライベート通信になる。コードの変更不要。

## 4. 既存ファイル変更詳細

### 4.1 ecs.tf（環境変数追加）

```hcl
# aws_ecs_task_definition.app の container_definitions に追加
environment = [
  { name = "DATABASE_URL",          value = "" },   # 既存（Secrets Manager 経由）
  { name = "SQS_QUEUE_URL",         value = aws_sqs_queue.task_events.url },       # 追加
  { name = "EVENTBRIDGE_BUS_NAME",  value = aws_cloudwatch_event_bus.main.name },  # 追加
  { name = "AWS_DEFAULT_REGION",    value = var.aws_region },                       # 追加
]
```

### 4.2 iam.tf（ECS タスクロールにポリシー追加）

```hcl
# 既存の aws_iam_role_policy.ecs_task に追記
Statement: [
  ...既存のポリシー（Secrets Manager 読み取りなど）,
  {
    Effect   = "Allow"
    Action   = ["sqs:SendMessage"]
    Resource = [aws_sqs_queue.task_events.arn]
  },
  {
    Effect   = "Allow"
    Action   = ["events:PutEvents"]
    Resource = [aws_cloudwatch_event_bus.main.arn]
  }
]
```

### 4.3 logs.tf（Lambda ロググループ追加）

```hcl
aws_cloudwatch_log_group "lambda_task_created":
  name              = "/aws/lambda/sample-cicd-task-created-handler"
  retention_in_days = 7
  tags = { Project = "sample-cicd" }

# task_completed_handler, task_cleanup_handler も同様
```

## 5. 変数設計（variables.tf 変更）

### v4 追加変数

| 変数名 | 型 | デフォルト値 | 説明 |
|--------|----|-------------|------|
| `lambda_log_retention_days` | number | `7` | Lambda CloudWatch Logs の保持日数 |
| `cleanup_schedule_expression` | string | `"cron(0 15 * * ? *)"` | クリーンアップ実行スケジュール（UTC） |
| `cleanup_retention_days` | number | `30` | 完了済みタスクの保持日数（これ以上経過したら削除） |

## 6. 出力値設計（outputs.tf 変更）

### v4 追加出力

| 出力名 | 値 | 用途 |
|--------|-----|------|
| `sqs_queue_url` | `aws_sqs_queue.task_events.url` | 動作確認・デバッグ |
| `eventbridge_bus_name` | `aws_cloudwatch_event_bus.main.name` | 動作確認・デバッグ |
| `lambda_task_created_arn` | `aws_lambda_function.task_created_handler.arn` | CD パイプラインでの参照 |
| `lambda_task_completed_arn` | `aws_lambda_function.task_completed_handler.arn` | CD パイプラインでの参照 |
| `lambda_task_cleanup_arn` | `aws_lambda_function.task_cleanup_handler.arn` | CD パイプラインでの参照 |

## 7. リソース依存関係（v4 追加分）

```
# SQS フロー
aws_sqs_queue.task_events_dlq
  └──▶ aws_sqs_queue.task_events (redrive_policy)
         └──▶ aws_lambda_event_source_mapping.task_created
                  └──▶ aws_lambda_function.task_created_handler
                         └──▶ aws_iam_role.lambda_task_created

# EventBridge フロー
aws_cloudwatch_event_bus.main
  └──▶ aws_cloudwatch_event_rule.task_completed
         └──▶ aws_cloudwatch_event_target.task_completed_lambda
                  └──▶ aws_lambda_function.task_completed_handler
                  └──▶ aws_lambda_permission.task_completed_eventbridge

# Scheduler フロー
aws_lambda_function.task_cleanup_handler (VPC設定あり)
  └──▶ aws_subnet.private_1, aws_subnet.private_2
  └──▶ aws_security_group.lambda_cleanup
         └──▶ aws_security_group.vpc_endpoint (経由)
                  └──▶ aws_vpc_endpoint.secretsmanager
                  └──▶ aws_vpc_endpoint.logs
aws_scheduler_schedule.task_cleanup
  └──▶ aws_lambda_function.task_cleanup_handler
  └──▶ aws_lambda_permission.task_cleanup_scheduler
```

## 8. State 管理（変更なし）

| 項目 | 値 |
|------|------|
| Backend | local |
| State file | `infra/terraform.tfstate` |
