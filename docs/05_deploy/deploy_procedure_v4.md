# デプロイ手順書 (v4)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-06 |
| バージョン | 4.0 |
| 前バージョン | [deploy_procedure_v3.md](deploy_procedure_v3.md) (v3.0) |

## 変更概要

v3 のデプロイ手順に対して以下の変更・追加を行う:

| # | 変更点 | 説明 |
|---|--------|------|
| 1 | SQS リソース追加 | DLQ + タスクイベントキュー + EventSourceMapping（Lambda トリガー） |
| 2 | Lambda 関数 3 つ追加 | task_created / task_completed / task_cleanup ハンドラー |
| 3 | EventBridge 追加 | カスタムバス + ルール + EventBridge Scheduler |
| 4 | VPC エンドポイント追加 | Secrets Manager / CloudWatch Logs（cleanup Lambda 用） |
| 5 | Lambda Layer 作成 | task_cleanup_handler の psycopg2 依存を Lambda Layer で提供 |
| 6 | ECS 環境変数追加 | `SQS_QUEUE_URL`、`EVENTBRIDGE_BUS_NAME`、`AWS_REGION` |
| 7 | CI/CD ワークフロー更新 | `lambda/` lint 追加、Lambda デプロイステップ追加 |
| 8 | IAM ユーザー権限追加 | `lambda:UpdateFunctionCode` を GitHub Actions 用 IAM ポリシーに追加 |

## 1. 前提条件

v3 のデプロイ手順完了済みであること（v3 リソースが `terraform apply` 済み）。

| 項目 | 要件 |
|------|------|
| AWS CLI v2 | インストール・設定済み |
| Terraform | インストール済み |
| Docker | インストール済み |
| Python 3.12 | インストール済み（Lambda Layer ビルド用） |
| v3 インフラ | `terraform apply` 済み、ECS サービスが稼働中 |
| pip | `pip install` が使用可能であること |

## 2. IAM ユーザー権限追加

GitHub Actions の CD ジョブで Lambda コードを更新するため、IAM ユーザーに追加権限が必要。

```bash
# 現在の IAM ポリシーを確認（ポリシー名は環境に合わせて変更）
aws iam list-attached-user-policies --user-name <CI_CD_IAM_USER>

# インラインポリシーを追加（既存ポリシーへの追記 または 新規追加）
aws iam put-user-policy \
  --user-name <CI_CD_IAM_USER> \
  --policy-name sample-cicd-lambda-deploy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": ["lambda:UpdateFunctionCode"],
      "Resource": [
        "arn:aws:lambda:ap-northeast-1:*:function:sample-cicd-task-created-handler",
        "arn:aws:lambda:ap-northeast-1:*:function:sample-cicd-task-completed-handler",
        "arn:aws:lambda:ap-northeast-1:*:function:sample-cicd-task-cleanup-handler"
      ]
    }]
  }'
```

## 3. Lambda Layer 作成（psycopg2 用）

`task_cleanup_handler` は `psycopg2` を使用するが、Lambda Python 3.12 ランタイムには含まれていない。
Lambda Layer を使って提供する。

> **注意**: psycopg2 は Amazon Linux 2 環境でビルドされたバイナリが必要。
> `aws-psycopg2` パッケージを使うか、Docker でビルドする。

### 3.1 Docker を使ったビルド（推奨）

```bash
mkdir -p /tmp/psycopg2-layer/python

docker run --rm \
  -v /tmp/psycopg2-layer:/layer \
  public.ecr.aws/lambda/python:3.12 \
  pip install psycopg2-binary -t /layer/python

cd /tmp/psycopg2-layer
zip -r psycopg2-layer.zip python/
```

### 3.2 Lambda Layer を発行

```bash
aws lambda publish-layer-version \
  --layer-name sample-cicd-psycopg2 \
  --description "psycopg2-binary for Python 3.12" \
  --zip-file fileb:///tmp/psycopg2-layer/psycopg2-layer.zip \
  --compatible-runtimes python3.12 \
  --region ap-northeast-1
```

出力された `LayerVersionArn` を控えておく。

### 3.3 Terraform に Layer ARN を追加

`infra/lambda.tf` の `task_cleanup_handler` に `layers` を追加する:

```hcl
resource "aws_lambda_function" "task_cleanup_handler" {
  # ... 既存設定 ...
  layers = ["<控えた LayerVersionArn>"]
}
```

または `infra/variables.tf` に変数として定義:

```hcl
variable "psycopg2_layer_arn" {
  description = "ARN of the psycopg2 Lambda Layer"
  type        = string
  default     = ""
}
```

そして `infra/lambda.tf` で:

```hcl
layers = var.psycopg2_layer_arn != "" ? [var.psycopg2_layer_arn] : []
```

`terraform.tfvars` に ARN を設定:

```hcl
psycopg2_layer_arn = "arn:aws:lambda:ap-northeast-1:<ACCOUNT_ID>:layer:sample-cicd-psycopg2:1"
```

## 4. Terraform init（archive プロバイダー追加済みのため再 init 必要）

v4 では `archive_file` データソースを使用するため、`hashicorp/archive` プロバイダーが必要。

```bash
cd ~/sample_cicd/infra
terraform init -upgrade
```

期待される出力例:

```
Initializing provider plugins...
- Finding latest version of hashicorp/archive...
- Installing hashicorp/archive v2.x.x...
```

## 5. 実行計画の確認

```bash
cd ~/sample_cicd/infra
terraform plan
```

以下の変更が表示されることを確認する:

| 変更種別 | リソース数 | 主なリソース |
|---------|-----------|-------------|
| `+` 追加 | 約 28 | SQS キュー×2、Lambda×3、EventBridge バス+ルール+スケジューラー、VPC エンドポイント×2、IAM ロール×3、SG×2 等 |
| `~` 変更 | 2 | ECS タスク定義（環境変数追加）、RDS SG（Lambda からのアクセス許可追加） |

期待される plan サマリ（おおよそ）:

```
Plan: 28 to add, 2 to change, 0 to destroy.
```

> 実際の数は環境により異なる場合がある。

## 6. インフラ更新の適用

```bash
terraform apply
```

`Enter a value:` に対して `yes` を入力する。

完了まで **約 5〜10 分** かかる。

完了後のメッセージ（おおよそ）:

```
Apply complete! Resources: 28 added, 2 changed, 0 destroyed.
```

## 7. デプロイ後リソース確認

### 7.1 SQS キューの確認

```bash
aws sqs list-queues --queue-name-prefix sample-cicd --region ap-northeast-1
```

期待される出力:

```json
{
  "QueueUrls": [
    "https://sqs.ap-northeast-1.amazonaws.com/<ACCOUNT_ID>/sample-cicd-task-events",
    "https://sqs.ap-northeast-1.amazonaws.com/<ACCOUNT_ID>/sample-cicd-task-events-dlq"
  ]
}
```

### 7.2 Lambda 関数の確認

```bash
aws lambda list-functions \
  --region ap-northeast-1 \
  --query 'Functions[?starts_with(FunctionName, `sample-cicd`)].{Name: FunctionName, State: State}'
```

期待される出力:

```json
[
  {"Name": "sample-cicd-task-cleanup-handler",   "State": "Active"},
  {"Name": "sample-cicd-task-completed-handler", "State": "Active"},
  {"Name": "sample-cicd-task-created-handler",   "State": "Active"}
]
```

### 7.3 EventBridge バスの確認

```bash
aws events list-event-buses \
  --region ap-northeast-1 \
  --query 'EventBuses[?Name==`sample-cicd-bus`]'
```

期待される出力:

```json
[{"Name": "sample-cicd-bus", "Arn": "arn:aws:events:ap-northeast-1:..."}]
```

### 7.4 EventBridge Scheduler の確認

```bash
aws scheduler list-schedules \
  --region ap-northeast-1 \
  --query 'Schedules[?Name==`sample-cicd-task-cleanup`]'
```

期待される出力: `sample-cicd-task-cleanup` スケジュールが 1 件

### 7.5 VPC エンドポイントの確認

```bash
aws ec2 describe-vpc-endpoints \
  --region ap-northeast-1 \
  --filters "Name=service-name,Values=com.amazonaws.ap-northeast-1.secretsmanager,com.amazonaws.ap-northeast-1.logs" \
  --query 'VpcEndpoints[].{Service: ServiceName, State: State}'
```

期待される出力: 2 件が `available`

## 8. 動作確認

### 8.1 SQS イベント確認（POST /tasks）

```bash
ALB_DNS=$(cd ~/sample_cicd/infra && terraform output -raw alb_dns_name)

# タスク作成
curl -s -X POST http://$ALB_DNS/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "v4 SQS test"}' | jq .

# Lambda ログ確認（最新の 10 件）
aws logs tail /aws/lambda/sample-cicd-task-created-handler \
  --since 1m \
  --region ap-northeast-1
```

期待されるログ出力:

```
Task created: task_id=<ID>, title=v4 SQS test
```

### 8.2 EventBridge イベント確認（PUT /tasks/{id} completed=true）

```bash
# タスク ID を確認（直前に作成したタスク）
TASK_ID=$(curl -s http://$ALB_DNS/tasks | jq '.[0].id')

# タスク完了
curl -s -X PUT http://$ALB_DNS/tasks/$TASK_ID \
  -H "Content-Type: application/json" \
  -d '{"completed": true}' | jq .

# Lambda ログ確認
aws logs tail /aws/lambda/sample-cicd-task-completed-handler \
  --since 1m \
  --region ap-northeast-1
```

期待されるログ出力:

```
Task completed: task_id=<ID>, title=v4 SQS test
```

### 8.3 Scheduler によるクリーンアップ Lambda の手動実行テスト

Scheduler は毎日 0:00 JST（UTC 15:00）に実行されるため、手動で起動してテストする。

```bash
# Lambda を直接呼び出し
aws lambda invoke \
  --function-name sample-cicd-task-cleanup-handler \
  --region ap-northeast-1 \
  --payload '{}' \
  /tmp/cleanup-output.json

cat /tmp/cleanup-output.json
```

期待される出力:

```json
{"deleted": 0}
```

> 保持期間（デフォルト 30 日）を超えた完了済みタスクがなければ `{"deleted": 0}` が返る。

ログ確認:

```bash
aws logs tail /aws/lambda/sample-cicd-task-cleanup-handler \
  --since 1m \
  --region ap-northeast-1
```

期待されるログ:

```
Cleanup done: deleted 0 tasks older than 30 days
```

## 9. CI/CD デプロイ確認

### 9.1 コードの push と CI/CD 実行

```bash
cd ~/sample_cicd
git add \
  app/services/ \
  app/routers/tasks.py \
  app/requirements.txt \
  lambda/ \
  infra/sqs.tf \
  infra/lambda.tf \
  infra/eventbridge.tf \
  infra/vpc_endpoints.tf \
  infra/iam.tf \
  infra/ecs.tf \
  infra/variables.tf \
  infra/logs.tf \
  infra/outputs.tf \
  tests/test_tasks.py \
  docs/ \
  .github/workflows/ci-cd.yml
git commit -m "v4: SQS + Lambda + EventBridge event-driven architecture"
git push origin main
```

### 9.2 CI ジョブの確認

GitHub Actions で以下が成功することを確認:

1. **Lint** — `ruff check app/ tests/ lambda/` がエラー 0 件
2. **Test** — `pytest tests/ -v` で **23 テスト** 全 PASS（TC-01〜TC-23）
3. **Build** — `docker build -f app/Dockerfile .` が成功

### 9.3 CD ジョブの確認

CD ジョブで以下が成功することを確認:

1. ECR にイメージが push される
2. ECS ローリングデプロイが完了する（`wait-for-service-stability: true`）
3. **Lambda 関数 3 つのコードが更新される**（`aws lambda update-function-code`）

## 10. クリーンアップ手順

> **重要**: v4 では VPC エンドポイント 2 本が追加され、コストが約 +$15/月 増加している（合計約 $75/月）。学習完了後は必ず削除すること。

### 10.1 費用が発生する主なリソース（v4 追加分）

| リソース | 概算費用 | 備考 |
|---------|---------|------|
| SQS（Standard Queue） | ほぼ $0 | 学習規模では 100 万リクエスト/月無料枠内 |
| Lambda（3 関数） | ほぼ $0 | 月 100 万リクエスト無料枠内 |
| EventBridge カスタムバス | ほぼ $0 | 100 万イベント/月 $1.00 |
| VPC エンドポイント ×2 | **約 $15/月** | $0.01/時間 × 2 本 × 730 時間 |

> v3 の約 $60/月 + $15/月 = **合計約 $75/月**

### 10.2 Terraform でリソース削除

```bash
cd ~/sample_cicd/infra

# ECR リポジトリ内のイメージを先に削除
aws ecr batch-delete-image \
  --repository-name sample-cicd \
  --image-ids "$(aws ecr list-images --repository-name sample-cicd --query 'imageIds[*]' --output json)" \
  --region ap-northeast-1

# 全リソース削除
terraform destroy
```

`Enter a value:` に対して `yes` を入力する。

> **SQS キューは空でないと削除エラーになる場合がある。** あらかじめ SQS コンソールでキューをパージするか、メッセージを削除してから `terraform destroy` を実行する。

### 10.3 Lambda Layer 削除

```bash
# 発行した Layer バージョンを削除
aws lambda delete-layer-version \
  --layer-name sample-cicd-psycopg2 \
  --version-number 1 \
  --region ap-northeast-1
```

## 11. トラブルシューティング

### v1〜v3 のトラブルシューティング

[deploy_procedure_v3.md](deploy_procedure_v3.md) セクション 7 を参照。

### v4 固有の問題

#### Lambda 作成時に `AWS_REGION` 予約語エラーになる

```
InvalidParameterValueException: Reserved keys used in this request: AWS_REGION
```

`AWS_REGION` は Lambda ランタイムが自動設定する予約済み環境変数のため、明示的に設定できない。
`infra/lambda.tf` の `task_cleanup_handler` の `environment` ブロックから `AWS_REGION` を削除する。
Lambda コード内の `os.environ.get("AWS_REGION", "ap-northeast-1")` は Lambda が自動設定する値を参照するため問題なし。

#### ECS タスクが Secrets Manager に接続できない（private_dns_enabled の影響）

```
ResourceInitializationError: unable to retrieve secret from asm: There is a connection issue between the task and AWS Secrets Manager.
```

VPC エンドポイントに `private_dns_enabled = true` を設定すると VPC 全体の DNS が上書きされ、
パブリックサブネットの ECS タスクも VPC エンドポイント経由で Secrets Manager にアクセスするようになる。
VPC エンドポイントの SG に ECS tasks SG からのアクセスを許可する必要がある:

```hcl
# infra/vpc_endpoints.tf に追加
resource "aws_security_group_rule" "vpce_from_ecs_tasks" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.vpc_endpoint.id
  source_security_group_id = aws_security_group.ecs_tasks.id
  description              = "HTTPS from ECS tasks"
}
```

#### `aws_security_group.rds` のインライン ingress と `aws_security_group_rule` の競合

`terraform apply` のたびに RDS SG の lambda_cleanup からのルールが削除される場合、
インライン ingress ブロックと別個の `aws_security_group_rule` リソースが競合している。
`security_groups.tf` の RDS SG に以下を追加:

```hcl
lifecycle {
  ignore_changes = [ingress]
}
```

その後、AWS CLI でルールを手動復旧:
```bash
aws ec2 authorize-security-group-ingress \
  --group-id <RDS_SG_ID> \
  --protocol tcp --port 5432 \
  --source-group <LAMBDA_CLEANUP_SG_ID> \
  --region ap-northeast-1
```

#### task_cleanup_handler が `No module named 'psycopg2'` でエラーになる

Lambda ランタイムに psycopg2 が含まれていないためのエラー。セクション 3 の Lambda Layer を作成して `layers` 設定を追加する。

#### SQS メッセージが DLQ に移動する

`task_created_handler` が 3 回失敗するとメッセージが DLQ に移動する。

```bash
# DLQ のメッセージ数確認
aws sqs get-queue-attributes \
  --queue-url $(aws sqs get-queue-url --queue-name sample-cicd-task-events-dlq --query 'QueueUrl' --output text) \
  --attribute-names ApproximateNumberOfMessages \
  --region ap-northeast-1
```

Lambda のエラーログを確認:

```bash
aws logs tail /aws/lambda/sample-cicd-task-created-handler \
  --since 30m \
  --region ap-northeast-1
```

#### EventBridge ルールが Lambda をトリガーしない

ルールのステータスと Lambda パーミッションを確認:

```bash
# ルールのステータス確認
aws events describe-rule \
  --name sample-cicd-task-completed \
  --event-bus-name sample-cicd-bus \
  --region ap-northeast-1 \
  --query 'State'

# Lambda パーミッション確認
aws lambda get-policy \
  --function-name sample-cicd-task-completed-handler \
  --region ap-northeast-1
```

#### VPC Lambda（task_cleanup）が Secrets Manager にアクセスできない

VPC エンドポイントのプライベート DNS が有効になっているか確認:

```bash
aws ec2 describe-vpc-endpoints \
  --region ap-northeast-1 \
  --filters "Name=service-name,Values=com.amazonaws.ap-northeast-1.secretsmanager" \
  --query 'VpcEndpoints[0].{State: State, PrivateDns: PrivateDnsEnabled}'
```

期待される出力: `{"State": "available", "PrivateDns": true}`

セキュリティグループのルールも確認:

```bash
# lambda_cleanup SG のアウトバウンドルール確認
aws ec2 describe-security-groups \
  --region ap-northeast-1 \
  --filters "Name=group-name,Values=sample-cicd-lambda-cleanup-sg" \
  --query 'SecurityGroups[0].IpPermissionsEgress'
```
