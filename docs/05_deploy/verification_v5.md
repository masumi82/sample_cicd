# 動作確認記録 (v5)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-06 |
| バージョン | 5.0 |
| 前バージョン | [verification_v4.md](verification_v4.md) (v4.0) |

## 1. 確認概要

本ドキュメントは `deploy_procedure_v5.md` に従ってデプロイを実施した後の動作確認記録である。
各項目を実施し、結果を記録する。

v5 では Terraform Workspace の導入により全リソース名が `sample-cicd-dev-*` パターンに変更される。
S3 + CloudFront による添付ファイル機能が追加される。

## 2. 環境情報

| 項目 | 値 |
|------|------|
| AWS アカウント ID | 123456789012 |
| AWS リージョン | ap-northeast-1 |
| Terraform Workspace | dev |
| ALB DNS 名 | (terraform output alb_dns_name で確認) |
| ECR リポジトリ URL | 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/sample-cicd-dev |
| RDS エンドポイント | (terraform output rds_endpoint で確認) |
| S3 バケット名 | sample-cicd-dev-attachments |
| CloudFront ドメイン名 | dXXXXXXXXXXXXX.cloudfront.net |
| CloudFront ディストリビューション ID | (terraform output cloudfront_distribution_id で確認) |
| SQS キュー URL | https://sqs.ap-northeast-1.amazonaws.com/123456789012/sample-cicd-dev-task-events |
| EventBridge バス名 | sample-cicd-dev-bus |
| GitHub リポジトリ URL | https://github.com/masumi82/sample_cicd |
| 実施日 | 2026-04-06 |
| 実施者 | m-horiuchi |

## 3. v4 インフラ破棄

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 1 | ECR イメージ削除 | `aws ecr batch-delete-image ...` | イメージ全件削除 | PASS | |
| 2 | SQS パージ | `aws sqs purge-queue ...` | キューが空になる | PASS | |
| 3 | terraform destroy 成功 | `terraform destroy` | "Destroy complete!" | PASS | |

## 4. Terraform Workspace 作成・適用

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 4 | Workspace 作成 | `terraform workspace new dev` | "Created and switched to workspace dev!" | PASS | |
| 5 | Workspace 確認 | `terraform workspace show` | `dev` | PASS | |
| 6 | terraform init 成功 | `terraform init -upgrade` | プロバイダー初期化成功 | PASS | |
| 7 | terraform plan 確認 | `terraform plan -var-file=dev.tfvars` | 79 to add, 0 to change, 0 to destroy | PASS | |
| 8 | terraform apply 成功 | `terraform apply -var-file=dev.tfvars` | "Apply complete!" | PASS | 2 回の apply（Layer バージョン不一致で 1 回目失敗） |

## 5. S3 バケット確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 9 | バケット存在確認 | `aws s3api head-bucket --bucket sample-cicd-dev-attachments` | 終了コード 0 | PASS | |
| 10 | 暗号化設定 | `aws s3api get-bucket-encryption ...` | `"AES256"` | PASS | |
| 11 | パブリックアクセスブロック | `aws s3api get-public-access-block ...` | 全項目 `true` | PASS | |
| 12 | CORS 設定 | `aws s3api get-bucket-cors ...` | AllowedMethods に PUT, AllowedOrigins に `*` | PASS | |

## 6. CloudFront 確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 13 | ディストリビューション存在 | `terraform output cloudfront_domain_name` | `d*.cloudfront.net` 形式のドメイン | PASS | dXXXXXXXXXXXXX.cloudfront.net |
| 14 | ディストリビューション状態 | AWS コンソールまたは CLI で確認 | Status: `Deployed` | PASS | |
| 15 | OAC 設定 | `aws cloudfront list-origin-access-controls` | `sample-cicd-dev-oac` が存在 | PASS | |

## 7. Workspace 命名確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 16 | ECS クラスタ名 | `aws ecs list-clusters` | `sample-cicd-dev` を含む | PASS | |
| 17 | ECS サービス名 | `aws ecs describe-services --cluster sample-cicd-dev --services sample-cicd-dev` | Status: `ACTIVE` | PASS | |
| 18 | Lambda 関数名 | `aws lambda list-functions ...` | 3 関数が `sample-cicd-dev-*` パターン | PASS | |
| 19 | SQS キュー名 | `aws sqs list-queues --queue-name-prefix sample-cicd-dev` | `sample-cicd-dev-task-events`, `sample-cicd-dev-task-events-dlq` | PASS | |
| 20 | EventBridge バス名 | `aws events list-event-buses ...` | `sample-cicd-dev-bus` が 1 件 | PASS | |
| 21 | RDS インスタンス名 | `aws rds describe-db-instances --db-instance-identifier sample-cicd-dev` | Status: `available`, MultiAZ: `false` | PASS | |
| 22 | S3 バケット名 | `aws s3api head-bucket --bucket sample-cicd-dev-attachments` | 終了コード 0 | PASS | |

## 8. 基本 API 動作確認

```bash
ALB_DNS=$(cd ~/sample_cicd/infra && terraform output -raw alb_dns_name)

curl -s http://$ALB_DNS/health | jq .
curl -s -X POST http://$ALB_DNS/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "v5 attachment test"}' | jq .
```

| # | 確認項目 | 期待結果 | 結果 | 備考 |
|---|---------|---------|------|------|
| 23 | GET /health | `{"status": "healthy"}` | PASS | |
| 24 | POST /tasks | HTTP 201、タスクオブジェクト | PASS | `{"id":1,"title":"v5 attachment test",...}` |

## 9. 添付ファイル — Presigned URL アップロード

```bash
TASK_ID=$(curl -s http://$ALB_DNS/tasks | jq '.[0].id')

UPLOAD_RESPONSE=$(curl -s -X POST http://$ALB_DNS/tasks/$TASK_ID/attachments \
  -H "Content-Type: application/json" \
  -d '{"filename": "test.txt", "content_type": "text/plain"}')
echo $UPLOAD_RESPONSE | jq .

UPLOAD_URL=$(echo $UPLOAD_RESPONSE | jq -r '.upload_url')
curl -X PUT "$UPLOAD_URL" \
  -H "Content-Type: text/plain" \
  -d "Hello from v5!"
```

| # | 確認項目 | 期待結果 | 結果 | 備考 |
|---|---------|---------|------|------|
| 25 | POST /tasks/{id}/attachments レスポンス | HTTP 201、`upload_url` が `https://` で始まる | PASS | `upload_url` が `https://s3.ap-northeast-1.amazonaws.com/...` 形式 |
| 26 | Presigned URL PUT アップロード | HTTP 200 | PASS | |
| 27 | S3 オブジェクト存在確認 | `aws s3 ls s3://sample-cicd-dev-attachments/tasks/$TASK_ID/` にファイルが存在 | PASS | 14 bytes |

## 10. 添付ファイル — CloudFront ダウンロード

```bash
ATTACHMENT_ID=$(curl -s http://$ALB_DNS/tasks/$TASK_ID/attachments | jq '.[0].id')

DOWNLOAD_URL=$(curl -s http://$ALB_DNS/tasks/$TASK_ID/attachments/$ATTACHMENT_ID | jq -r '.download_url')
echo "Download URL: $DOWNLOAD_URL"

curl -s "$DOWNLOAD_URL"
```

| # | 確認項目 | 期待結果 | 結果 | 備考 |
|---|---------|---------|------|------|
| 28 | GET /tasks/{id}/attachments 一覧 | 1 件の添付ファイルが返却される | PASS | |
| 29 | GET /tasks/{id}/attachments/{id} レスポンス | `download_url` が `https://d*.cloudfront.net/tasks/...` 形式 | PASS | `https://dXXXXXXXXXXXXX.cloudfront.net/tasks/1/...` |
| 30 | CloudFront 経由ダウンロード | `Hello from v5!` が返却される | PASS | |

## 11. 添付ファイル — 削除

```bash
curl -s -X DELETE http://$ALB_DNS/tasks/$TASK_ID/attachments/$ATTACHMENT_ID -w "\n%{http_code}\n"

aws s3 ls s3://sample-cicd-dev-attachments/tasks/$TASK_ID/ --region ap-northeast-1
```

| # | 確認項目 | 期待結果 | 結果 | 備考 |
|---|---------|---------|------|------|
| 31 | DELETE /tasks/{id}/attachments/{id} | HTTP 204 | PASS | |
| 32 | S3 オブジェクト削除確認 | 該当パス配下が空 | PASS | |

## 12. タスク削除時の S3 一括削除

```bash
TASK_ID2=$(curl -s -X POST http://$ALB_DNS/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "bulk delete test"}' | jq '.id')

curl -s -X POST http://$ALB_DNS/tasks/$TASK_ID2/attachments \
  -H "Content-Type: application/json" \
  -d '{"filename": "file1.txt", "content_type": "text/plain"}' > /dev/null

curl -s -X POST http://$ALB_DNS/tasks/$TASK_ID2/attachments \
  -H "Content-Type: application/json" \
  -d '{"filename": "file2.txt", "content_type": "text/plain"}' > /dev/null

curl -s -X DELETE http://$ALB_DNS/tasks/$TASK_ID2 -w "\n%{http_code}\n"
aws s3 ls s3://sample-cicd-dev-attachments/tasks/$TASK_ID2/ --region ap-northeast-1
```

| # | 確認項目 | 期待結果 | 結果 | 備考 |
|---|---------|---------|------|------|
| 33 | DELETE /tasks/{id} | HTTP 204 | PASS | |
| 34 | S3 オブジェクト一括削除確認 | 該当タスク配下が空 | PASS | |

## 13. SQS / EventBridge イベント確認（v4 機能の継続動作）

```bash
aws logs tail /aws/lambda/sample-cicd-dev-task-created-handler --since 30m --region ap-northeast-1
aws logs tail /aws/lambda/sample-cicd-dev-task-completed-handler --since 5m --region ap-northeast-1
```

| # | 確認項目 | 期待結果 | 結果 | 備考 |
|---|---------|---------|------|------|
| 35 | task_created_handler Lambda ログ | `Task created: task_id=...` が出力される | PASS | `Task created: task_id=1, title=v5 attachment test`（処理時間 2.47ms） |
| 36 | task_completed_handler Lambda ログ | `Task completed: task_id=...` が出力される | PASS | `Task completed: task_id=1, title=v5 attachment test`（処理時間 2.10ms） |

## 14. CI/CD パイプライン確認

| # | 確認項目 | 確認方法 | 期待結果 | 結果 | 備考 |
|---|---------|---------|---------|------|------|
| 37 | CI — Lint | GitHub Actions ログ | `ruff check app/ tests/ lambda/` エラー 0 件 | PASS | |
| 38 | CI — Test | GitHub Actions ログ | 46 tests passed（TC-01〜TC-39） | PASS | |
| 39 | CI — Build | GitHub Actions ログ | `docker build` 成功 | PASS | |
| 40 | CD — ECR Push | GitHub Actions ログ | `sample-cicd-dev` リポジトリへ push 成功 | PASS | IAM ポリシー v3 更新後に成功 |
| 41 | CD — ECS Deploy | GitHub Actions ログ | `sample-cicd-dev` サービスへデプロイ完了 | PASS | |
| 42 | CD — Lambda Deploy | GitHub Actions ログ | `sample-cicd-dev-task-*-handler` 3 関数の update-function-code 成功 | PASS | |

## 15. 確認結果サマリ

| カテゴリ | 合計 | PASS | FAIL | 合格率 |
|---------|------|------|------|--------|
| v4 インフラ破棄 (#1-3) | 3 | 3 | 0 | 100% |
| Workspace 作成・適用 (#4-8) | 5 | 5 | 0 | 100% |
| S3 バケット (#9-12) | 4 | 4 | 0 | 100% |
| CloudFront (#13-15) | 3 | 3 | 0 | 100% |
| Workspace 命名 (#16-22) | 7 | 7 | 0 | 100% |
| 基本 API (#23-24) | 2 | 2 | 0 | 100% |
| Presigned URL アップロード (#25-27) | 3 | 3 | 0 | 100% |
| CloudFront ダウンロード (#28-30) | 3 | 3 | 0 | 100% |
| 添付ファイル削除 (#31-32) | 2 | 2 | 0 | 100% |
| タスク削除時 S3 一括削除 (#33-34) | 2 | 2 | 0 | 100% |
| SQS/EventBridge (#35-36) | 2 | 2 | 0 | 100% |
| CI/CD (#37-42) | 6 | 6 | 0 | 100% |
| **合計** | **42** | **42** | **0** | **100%** |

## 16. 判定

- ☑ **合格** — 全 42 項目が PASS
- ☐ **条件付き合格**
- ☐ **不合格**

### 判定者コメント

全 42 項目 PASS。S3 Presigned URL アップロード → CloudFront OAC 経由ダウンロード → 添付ファイル削除（S3 連動）の一連のフローが正常動作を確認。Terraform Workspace による全リソース名 `sample-cicd-dev-*` パターンへの統一も確認済み。v4 イベント駆動機能（SQS → Lambda、EventBridge → Lambda）も継続動作。CI/CD パイプラインは 46 テスト PASS・ECR push・ECS デプロイ・Lambda 3 関数デプロイすべて成功。

### 検出された問題と対応

| # | 問題 | 原因 | 対応 |
|---|------|------|------|
| 1 | Lambda Layer バージョン不一致 | `dev.tfvars` が `:1` を参照していたが、Layer 再作成で `:2` になった | `dev.tfvars` の `psycopg2_layer_arn` を `:2` に更新後、`terraform apply` 再実行 |
| 2 | ECR イメージ未 push で ECS タスク起動失敗 | 新規 ECR リポジトリ `sample-cicd-dev` にイメージがない | 手動で `docker build` → `docker push` → ECS 再デプロイ |
| 3 | Presigned URL で TemporaryRedirect エラー | boto3 S3 クライアントがグローバルエンドポイント（`s3.amazonaws.com`）で URL を生成し、`ap-northeast-1` バケットへのリダイレクトが発生 | `storage.py` に `endpoint_url` でリージョナルエンドポイントを明示 + `signature_version="s3v4"` を追加 |
| 4 | GitHub Actions ECR push 権限エラー | IAM ポリシーが旧リポジトリ名 `sample-cicd` を参照 | マネージドポリシーを v3 に更新し、全リソース ARN を `sample-cicd-dev` に変更 |

## 17. クリーンアップ記録

| # | 作業項目 | 実施日 | 結果 | 備考 |
|---|---------|--------|------|------|
| 1 | S3 オブジェクト全削除 | | ☐ | `aws s3 rm s3://sample-cicd-dev-attachments --recursive` |
| 2 | ECR イメージ削除 | | ☐ | |
| 3 | SQS パージ | | ☐ | |
| 4 | `terraform destroy -var-file=dev.tfvars` 実行 | | ☐ | |
| 5 | IAM ポリシー更新（必要に応じて） | | ☐ | |
