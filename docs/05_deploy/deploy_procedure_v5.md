# デプロイ手順書 (v5)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-06 |
| バージョン | 5.0 |
| 前バージョン | [deploy_procedure_v4.md](deploy_procedure_v4.md) (v4.0) |

## 変更概要

v4 のデプロイ手順に対して以下の変更・追加を行う:

| # | 変更点 | 説明 |
|---|--------|------|
| 1 | Terraform Workspace 導入 | `default` → `dev` ワークスペース。全リソース名が `sample-cicd-dev-*` に変更 |
| 2 | S3 バケット追加 | ファイル添付用。暗号化 (SSE-S3) + パブリックアクセスブロック + CORS |
| 3 | CloudFront ディストリビューション追加 | OAC 経由で S3 からファイル配信 |
| 4 | 添付ファイル API 追加 | `POST/GET/DELETE /tasks/{id}/attachments` エンドポイント |
| 5 | Alembic マイグレーション追加 | `attachments` テーブル作成 |
| 6 | ECS 環境変数追加 | `S3_BUCKET_NAME`、`CLOUDFRONT_DOMAIN_NAME` |
| 7 | IAM 権限追加 | ECS タスクロールに `s3:PutObject`, `s3:DeleteObject` |
| 8 | CI/CD Workspace 対応 | `DEPLOY_ENV=dev` 環境変数、全リソース名に環境名を付与 |
| 9 | tfvars ファイル分割 | `terraform.tfvars` → `dev.tfvars` / `prod.tfvars` |

> **重要**: Workspace 導入により全リソース名が変更されるため、v4 インフラを一度破棄してから v5 を新規構築する。

## 1. 前提条件

| 項目 | 要件 |
|------|------|
| AWS CLI v2 | インストール・設定済み |
| Terraform | インストール済み |
| Docker | インストール済み |
| Python 3.12 | インストール済み |
| v4 インフラ | `terraform apply` 済み（破棄対象） |
| psycopg2 Layer | v4 で作成済み |

## 2. v4 インフラの破棄

v5 では全リソース名が `sample-cicd` → `sample-cicd-dev` に変更されるため、v4 リソースを先に破棄する。

> **注意**: `terraform state mv` による移行も可能だが、リソース数が多いため破棄→再構築の方が確実。

### 2.1 ECR イメージの削除

```bash
aws ecr batch-delete-image \
  --repository-name sample-cicd \
  --image-ids "$(aws ecr list-images --repository-name sample-cicd --query 'imageIds[*]' --output json)" \
  --region ap-northeast-1
```

### 2.2 SQS キューのパージ

```bash
QUEUE_URL=$(aws sqs get-queue-url --queue-name sample-cicd-task-events --query 'QueueUrl' --output text --region ap-northeast-1)
aws sqs purge-queue --queue-url $QUEUE_URL --region ap-northeast-1
```

### 2.3 Terraform destroy

```bash
cd ~/sample_cicd/infra
terraform workspace select default
terraform destroy
```

`Enter a value:` に `yes` を入力。完了まで約 5〜10 分。

### 2.4 psycopg2 Lambda Layer の再作成

v4 の `terraform destroy` で Lambda Layer は削除されないが、手動で削除済みの場合は再作成が必要。

```bash
cd ~/sample_cicd
pip install psycopg2-binary -t python/lib/python3.12/site-packages/ \
  --platform manylinux2014_x86_64 --only-binary=:all:
zip -r psycopg2-layer.zip python/
aws lambda publish-layer-version \
  --layer-name sample-cicd-psycopg2 \
  --zip-file fileb://psycopg2-layer.zip \
  --compatible-runtimes python3.12 \
  --region ap-northeast-1
rm -rf python/ psycopg2-layer.zip
```

> Layer が存在しない状態で `terraform apply` すると `InvalidParameterValueException: Layer version ... does not exist` エラーになる。

## 3. Terraform Workspace 作成

```bash
cd ~/sample_cicd/infra
terraform workspace new dev
```

期待される出力:

```
Created and switched to workspace "dev"!
```

確認:

```bash
terraform workspace show
# → dev
```

## 4. Terraform init

```bash
terraform init -upgrade
```

## 5. 実行計画の確認

```bash
terraform plan -var-file=dev.tfvars
```

以下の変更が表示されることを確認する:

| 変更種別 | リソース数 | 主なリソース |
|---------|-----------|-------------|
| `+` 追加 | 79 | VPC, サブネット, ALB, ECS, RDS, SQS, Lambda×3, EventBridge, S3, CloudFront 等 |

> v4 を破棄した後の新規構築のため、全リソースが `+` 追加となる。

期待される plan サマリ:

```
Plan: 79 to add, 0 to change, 0 to destroy.
```

v5 で新規追加されるリソース:

| リソース | 説明 |
|---------|------|
| `aws_s3_bucket.attachments` | ファイル添付用バケット (`sample-cicd-dev-attachments`) |
| `aws_s3_bucket_public_access_block.attachments` | パブリックアクセスブロック |
| `aws_s3_bucket_policy.attachments` | CloudFront OAC のみ許可 |
| `aws_s3_bucket_cors_configuration.attachments` | Presigned URL アップロード用 CORS |
| `aws_s3_bucket_server_side_encryption_configuration.attachments` | SSE-S3 暗号化 |
| `aws_s3_bucket_versioning.attachments` | バージョニング (dev: Suspended) |
| `aws_cloudfront_origin_access_control.s3` | OAC |
| `aws_cloudfront_distribution.attachments` | CDN ディストリビューション |

## 6. インフラ構築の適用

```bash
terraform apply -var-file=dev.tfvars
```

`Enter a value:` に `yes` を入力。完了まで **約 10〜15 分**。

> CloudFront ディストリビューションの作成に数分かかる。

完了後のメッセージ（おおよそ）:

```
Apply complete! Resources: 79 added, 0 changed, 0 destroyed.

Outputs:

alb_dns_name               = "sample-cicd-dev-alb-xxxxxxxxx.ap-northeast-1.elb.amazonaws.com"
cloudfront_distribution_id = "E1234ABCDEF"
cloudfront_domain_name     = "d1234abcdef.cloudfront.net"
ecr_repository_url         = "123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/sample-cicd-dev"
ecs_cluster_name           = "sample-cicd-dev"
ecs_service_name           = "sample-cicd-dev"
eventbridge_bus_name       = "sample-cicd-dev-bus"
rds_endpoint               = "(実行時に確定)"
s3_bucket_name             = "sample-cicd-dev-attachments"
sqs_queue_url              = "(実行時に確定)"
...
```

## 7. デプロイ後リソース確認

### 7.1 S3 バケットの確認

```bash
aws s3api head-bucket --bucket sample-cicd-dev-attachments --region ap-northeast-1
echo $?  # → 0 なら存在する
```

暗号化設定の確認:

```bash
aws s3api get-bucket-encryption --bucket sample-cicd-dev-attachments --region ap-northeast-1 \
  --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm'
```

期待される出力: `"AES256"`

パブリックアクセスブロックの確認:

```bash
aws s3api get-public-access-block --bucket sample-cicd-dev-attachments --region ap-northeast-1
```

期待される出力: 全項目 `true`

### 7.2 CloudFront の確認

```bash
CF_DOMAIN=$(cd ~/sample_cicd/infra && terraform output -raw cloudfront_domain_name)
echo "CloudFront domain: $CF_DOMAIN"
```

### 7.3 ECS サービスの確認

```bash
aws ecs describe-services \
  --cluster sample-cicd-dev \
  --services sample-cicd-dev \
  --region ap-northeast-1 \
  --query 'services[0].{Status: status, Running: runningCount, Desired: desiredCount}'
```

期待される出力:

```json
{"Status": "ACTIVE", "Running": 1, "Desired": 1}
```

### 7.4 全リソース名の Workspace 命名確認

```bash
# Lambda 関数名が sample-cicd-dev-* パターンであること
aws lambda list-functions \
  --region ap-northeast-1 \
  --query 'Functions[?starts_with(FunctionName, `sample-cicd-dev`)].FunctionName'

# SQS キュー名が sample-cicd-dev-* パターンであること
aws sqs list-queues --queue-name-prefix sample-cicd-dev --region ap-northeast-1
```

### 7.5 RDS の確認

```bash
aws rds describe-db-instances \
  --db-instance-identifier sample-cicd-dev \
  --region ap-northeast-1 \
  --query 'DBInstances[0].{Status: DBInstanceStatus, MultiAZ: MultiAZ, Engine: Engine}'
```

期待される出力:

```json
{"Status": "available", "MultiAZ": false, "Engine": "postgres"}
```

> dev 環境では `db_multi_az = false`。

## 8. 動作確認

### 8.1 基本 API の確認

```bash
ALB_DNS=$(cd ~/sample_cicd/infra && terraform output -raw alb_dns_name)

# ヘルスチェック
curl -s http://$ALB_DNS/health | jq .

# タスク作成
curl -s -X POST http://$ALB_DNS/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "v5 attachment test"}' | jq .
```

### 8.2 添付ファイルアップロード（Presigned URL）

```bash
TASK_ID=$(curl -s http://$ALB_DNS/tasks | jq '.[0].id')

# Presigned URL 取得
UPLOAD_RESPONSE=$(curl -s -X POST http://$ALB_DNS/tasks/$TASK_ID/attachments \
  -H "Content-Type: application/json" \
  -d '{"filename": "test.txt", "content_type": "text/plain"}')
echo $UPLOAD_RESPONSE | jq .

# Presigned URL を使ってアップロード
UPLOAD_URL=$(echo $UPLOAD_RESPONSE | jq -r '.upload_url')
curl -X PUT "$UPLOAD_URL" \
  -H "Content-Type: text/plain" \
  -d "Hello from v5!"
```

期待される結果: HTTP 200（アップロード成功）

### 8.3 添付ファイル一覧・取得

```bash
# 一覧取得
curl -s http://$ALB_DNS/tasks/$TASK_ID/attachments | jq .

# 個別取得（CloudFront download URL 付き）
ATTACHMENT_ID=$(curl -s http://$ALB_DNS/tasks/$TASK_ID/attachments | jq '.[0].id')
curl -s http://$ALB_DNS/tasks/$TASK_ID/attachments/$ATTACHMENT_ID | jq .
```

`download_url` が `https://d1234abcdef.cloudfront.net/tasks/...` の形式であることを確認。

### 8.4 CloudFront 経由のダウンロード

```bash
DOWNLOAD_URL=$(curl -s http://$ALB_DNS/tasks/$TASK_ID/attachments/$ATTACHMENT_ID | jq -r '.download_url')
curl -s "$DOWNLOAD_URL"
```

期待される出力: `Hello from v5!`

### 8.5 添付ファイル削除

```bash
curl -s -X DELETE http://$ALB_DNS/tasks/$TASK_ID/attachments/$ATTACHMENT_ID -w "\n%{http_code}\n"
```

期待される出力: `204`

S3 オブジェクトが削除されたことを確認:

```bash
aws s3 ls s3://sample-cicd-dev-attachments/tasks/$TASK_ID/ --region ap-northeast-1
# → 空であること
```

### 8.6 SQS / EventBridge イベント確認（v4 機能の継続動作）

```bash
# タスク作成 → task_created Lambda ログ確認
aws logs tail /aws/lambda/sample-cicd-dev-task-created-handler --since 2m --region ap-northeast-1

# タスク完了 → task_completed Lambda ログ確認
curl -s -X PUT http://$ALB_DNS/tasks/$TASK_ID \
  -H "Content-Type: application/json" \
  -d '{"completed": true}' | jq .
aws logs tail /aws/lambda/sample-cicd-dev-task-completed-handler --since 1m --region ap-northeast-1
```

## 9. IAM ユーザー権限更新

v5 では Lambda 関数名が変更されたため、CI/CD 用 IAM ポリシーのリソース ARN を更新する。

```bash
aws iam put-user-policy \
  --user-name <CI_CD_IAM_USER> \
  --policy-name sample-cicd-lambda-deploy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": ["lambda:UpdateFunctionCode"],
      "Resource": [
        "arn:aws:lambda:ap-northeast-1:*:function:sample-cicd-dev-task-created-handler",
        "arn:aws:lambda:ap-northeast-1:*:function:sample-cicd-dev-task-completed-handler",
        "arn:aws:lambda:ap-northeast-1:*:function:sample-cicd-dev-task-cleanup-handler"
      ]
    }]
  }'
```

## 10. CI/CD デプロイ確認

### 10.1 コードの push

```bash
cd ~/sample_cicd
git add -A
git commit -m "v5: S3 + CloudFront + Terraform Workspace"
git push origin main
```

### 10.2 CI ジョブの確認

1. **Lint** — `ruff check app/ tests/ lambda/` エラー 0 件
2. **Test** — `pytest tests/ -v` で **46 テスト** 全 PASS（TC-01〜TC-39）
3. **Build** — Docker イメージビルド成功

### 10.3 CD ジョブの確認

1. ECR リポジトリ名が `sample-cicd-dev` であること
2. ECS クラスタ/サービス名が `sample-cicd-dev` であること
3. Lambda 関数名が `sample-cicd-dev-task-*-handler` であること

## 11. クリーンアップ手順

> **重要**: v5 では CloudFront ディストリビューションが追加される。CloudFront 自体は無料枠内で費用は微少だが、全体コストは v4 と同程度（約 $75/月）。学習完了後は必ず削除すること。

### 11.1 費用が発生する主なリソース（v5 追加分）

| リソース | 概算費用 | 備考 |
|---------|---------|------|
| S3 バケット | ほぼ $0 | 学習規模では無料枠内 |
| CloudFront | ほぼ $0 | 月 1TB 転送まで無料枠内 |
| v4 リソース（VPC エンドポイント等） | 約 $15/月 | 変更なし |

### 11.2 Terraform でリソース削除

```bash
cd ~/sample_cicd/infra
terraform workspace select dev

# ECR イメージ削除
aws ecr batch-delete-image \
  --repository-name sample-cicd-dev \
  --image-ids "$(aws ecr list-images --repository-name sample-cicd-dev --query 'imageIds[*]' --output json)" \
  --region ap-northeast-1

# S3 バケット内オブジェクト削除（バケットが空でないと destroy 失敗）
aws s3 rm s3://sample-cicd-dev-attachments --recursive --region ap-northeast-1

# SQS パージ
QUEUE_URL=$(aws sqs get-queue-url --queue-name sample-cicd-dev-task-events --query 'QueueUrl' --output text --region ap-northeast-1)
aws sqs purge-queue --queue-url $QUEUE_URL --region ap-northeast-1

# 全リソース削除
terraform destroy -var-file=dev.tfvars
```

### 11.3 Lambda Layer 削除

```bash
# バージョン番号は実際の値に置き換えること（v5 デプロイ時は 2）
aws lambda delete-layer-version \
  --layer-name sample-cicd-psycopg2 \
  --version-number 2 \
  --region ap-northeast-1
```

## 12. トラブルシューティング

### v1〜v4 のトラブルシューティング

[deploy_procedure_v4.md](deploy_procedure_v4.md) セクション 11 を参照。

### v5 固有の問題

#### CloudFront ディストリビューション作成が遅い

CloudFront の初回作成は **15〜30 分** かかることがある。`terraform apply` がタイムアウトした場合は再実行する。

#### S3 バケットが `terraform destroy` で削除できない

バケットにオブジェクトが残っている場合、削除に失敗する。先に `aws s3 rm s3://sample-cicd-dev-attachments --recursive` でオブジェクトを削除する。バージョニングが有効な場合は削除マーカーも含めて全削除が必要:

```bash
aws s3api list-object-versions --bucket sample-cicd-dev-attachments \
  --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
  --output json | \
  aws s3api delete-objects --bucket sample-cicd-dev-attachments --delete file:///dev/stdin
```

#### Presigned URL で 403 Forbidden

ECS タスクロールに `s3:PutObject` 権限があるか確認。Presigned URL は署名時のロールの権限で認可される。

```bash
aws iam list-role-policies --role-name sample-cicd-dev-ecs-task-role
aws iam get-role-policy --role-name sample-cicd-dev-ecs-task-role --policy-name <POLICY_NAME>
```

#### CloudFront 経由で 403 AccessDenied

OAC 設定とバケットポリシーを確認:

```bash
# バケットポリシーの確認
aws s3api get-bucket-policy --bucket sample-cicd-dev-attachments | jq '.Policy | fromjson'
```

ポリシーの `Condition.StringEquals["AWS:SourceArn"]` が CloudFront ディストリビューションの ARN と一致していることを確認。

#### Workspace 切り替え後に `terraform plan` でエラー

`terraform.tfstate.d/dev/` ディレクトリにステートファイルが正しく保存されているか確認:

```bash
ls -la infra/terraform.tfstate.d/dev/
terraform workspace show  # → dev であること
```
