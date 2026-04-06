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
| AWS アカウント ID | (実施時に記入) |
| AWS リージョン | ap-northeast-1 |
| Terraform Workspace | dev |
| ALB DNS 名 | (実施時に記入) |
| ECR リポジトリ URL | (実施時に記入) |
| RDS エンドポイント | (実施時に記入) |
| S3 バケット名 | sample-cicd-dev-attachments |
| CloudFront ドメイン名 | (実施時に記入) |
| CloudFront ディストリビューション ID | (実施時に記入) |
| SQS キュー URL | (実施時に記入) |
| EventBridge バス名 | sample-cicd-dev-bus |
| GitHub リポジトリ URL | https://github.com/masumi82/sample_cicd |
| 実施日 | (実施時に記入) |
| 実施者 | (実施時に記入) |

## 3. v4 インフラ破棄

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 1 | ECR イメージ削除 | `aws ecr batch-delete-image ...` | イメージ全件削除 | | |
| 2 | SQS パージ | `aws sqs purge-queue ...` | キューが空になる | | |
| 3 | terraform destroy 成功 | `terraform destroy` | "Destroy complete!" | | |

## 4. Terraform Workspace 作成・適用

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 4 | Workspace 作成 | `terraform workspace new dev` | "Created and switched to workspace dev!" | | |
| 5 | Workspace 確認 | `terraform workspace show` | `dev` | | |
| 6 | terraform init 成功 | `terraform init -upgrade` | プロバイダー初期化成功 | | |
| 7 | terraform plan 確認 | `terraform plan -var-file=dev.tfvars` | 約 60 to add, 0 to change, 0 to destroy | | |
| 8 | terraform apply 成功 | `terraform apply -var-file=dev.tfvars` | "Apply complete!" | | |

## 5. S3 バケット確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 9 | バケット存在確認 | `aws s3api head-bucket --bucket sample-cicd-dev-attachments` | 終了コード 0 | | |
| 10 | 暗号化設定 | `aws s3api get-bucket-encryption --bucket sample-cicd-dev-attachments --query '..SSEAlgorithm'` | `"AES256"` | | |
| 11 | パブリックアクセスブロック | `aws s3api get-public-access-block --bucket sample-cicd-dev-attachments` | 全項目 `true` | | |
| 12 | CORS 設定 | `aws s3api get-bucket-cors --bucket sample-cicd-dev-attachments` | AllowedMethods に PUT, AllowedOrigins に `*` | | |

## 6. CloudFront 確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 13 | ディストリビューション存在 | `terraform output cloudfront_domain_name` | `d*.cloudfront.net` 形式のドメイン | | |
| 14 | ディストリビューション状態 | AWS コンソールまたは CLI で確認 | Status: `Deployed` | | |
| 15 | OAC 設定 | `aws cloudfront list-origin-access-controls` | `sample-cicd-dev-oac` が存在 | | |

## 7. Workspace 命名確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 16 | ECS クラスタ名 | `aws ecs list-clusters --query 'clusterArns'` | `sample-cicd-dev` を含む | | |
| 17 | ECS サービス名 | `aws ecs describe-services --cluster sample-cicd-dev --services sample-cicd-dev` | Status: `ACTIVE` | | |
| 18 | Lambda 関数名 | `aws lambda list-functions --query 'Functions[?starts_with(FunctionName, \`sample-cicd-dev\`)].FunctionName'` | 3 関数が `sample-cicd-dev-*` パターン | | |
| 19 | SQS キュー名 | `aws sqs list-queues --queue-name-prefix sample-cicd-dev` | `sample-cicd-dev-task-events`, `sample-cicd-dev-task-events-dlq` | | |
| 20 | EventBridge バス名 | `aws events list-event-buses --query 'EventBuses[?Name==\`sample-cicd-dev-bus\`]'` | `sample-cicd-dev-bus` が 1 件 | | |
| 21 | RDS インスタンス名 | `aws rds describe-db-instances --db-instance-identifier sample-cicd-dev` | Status: `available`, MultiAZ: `false` | | |
| 22 | S3 バケット名 | `aws s3api head-bucket --bucket sample-cicd-dev-attachments` | 終了コード 0 | | |

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
| 23 | GET /health | `{"status": "healthy"}` | | |
| 24 | POST /tasks | HTTP 201、タスクオブジェクト | | |

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
| 25 | POST /tasks/{id}/attachments レスポンス | HTTP 201、`upload_url` が `https://` で始まる | | |
| 26 | Presigned URL PUT アップロード | HTTP 200 | | |
| 27 | S3 オブジェクト存在確認 | `aws s3 ls s3://sample-cicd-dev-attachments/tasks/$TASK_ID/` にファイルが存在 | | |

## 10. 添付ファイル — CloudFront ダウンロード

```bash
ATTACHMENT_ID=$(curl -s http://$ALB_DNS/tasks/$TASK_ID/attachments | jq '.[0].id')

# download_url 取得
DOWNLOAD_URL=$(curl -s http://$ALB_DNS/tasks/$TASK_ID/attachments/$ATTACHMENT_ID | jq -r '.download_url')
echo "Download URL: $DOWNLOAD_URL"

# CloudFront 経由でダウンロード
curl -s "$DOWNLOAD_URL"
```

| # | 確認項目 | 期待結果 | 結果 | 備考 |
|---|---------|---------|------|------|
| 28 | GET /tasks/{id}/attachments 一覧 | 1 件の添付ファイルが返却される | | |
| 29 | GET /tasks/{id}/attachments/{id} レスポンス | `download_url` が `https://d*.cloudfront.net/tasks/...` 形式 | | |
| 30 | CloudFront 経由ダウンロード | `Hello from v5!` が返却される | | |

## 11. 添付ファイル — 削除

```bash
curl -s -X DELETE http://$ALB_DNS/tasks/$TASK_ID/attachments/$ATTACHMENT_ID -w "\n%{http_code}\n"

# S3 オブジェクトが削除されたことを確認
aws s3 ls s3://sample-cicd-dev-attachments/tasks/$TASK_ID/ --region ap-northeast-1
```

| # | 確認項目 | 期待結果 | 結果 | 備考 |
|---|---------|---------|------|------|
| 31 | DELETE /tasks/{id}/attachments/{id} | HTTP 204 | | |
| 32 | S3 オブジェクト削除確認 | 該当パス配下が空 | | |

## 12. タスク削除時の S3 一括削除

```bash
# テスト用タスクに添付ファイルを 2 つ追加
TASK_ID2=$(curl -s -X POST http://$ALB_DNS/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "bulk delete test"}' | jq '.id')

curl -s -X POST http://$ALB_DNS/tasks/$TASK_ID2/attachments \
  -H "Content-Type: application/json" \
  -d '{"filename": "file1.txt", "content_type": "text/plain"}' > /dev/null

curl -s -X POST http://$ALB_DNS/tasks/$TASK_ID2/attachments \
  -H "Content-Type: application/json" \
  -d '{"filename": "file2.txt", "content_type": "text/plain"}' > /dev/null

# タスクごと削除
curl -s -X DELETE http://$ALB_DNS/tasks/$TASK_ID2 -w "\n%{http_code}\n"
aws s3 ls s3://sample-cicd-dev-attachments/tasks/$TASK_ID2/ --region ap-northeast-1
```

| # | 確認項目 | 期待結果 | 結果 | 備考 |
|---|---------|---------|------|------|
| 33 | DELETE /tasks/{id} | HTTP 204 | | |
| 34 | S3 オブジェクト一括削除確認 | 該当タスク配下が空 | | |

## 13. SQS / EventBridge イベント確認（v4 機能の継続動作）

```bash
# タスク作成 → task_created Lambda ログ
aws logs tail /aws/lambda/sample-cicd-dev-task-created-handler --since 2m --region ap-northeast-1

# タスク完了 → task_completed Lambda ログ
TASK_ID3=$(curl -s -X POST http://$ALB_DNS/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "v4 event test"}' | jq '.id')

curl -s -X PUT http://$ALB_DNS/tasks/$TASK_ID3 \
  -H "Content-Type: application/json" \
  -d '{"completed": true}' | jq .

aws logs tail /aws/lambda/sample-cicd-dev-task-completed-handler --since 1m --region ap-northeast-1
```

| # | 確認項目 | 期待結果 | 結果 | 備考 |
|---|---------|---------|------|------|
| 35 | task_created_handler Lambda ログ | `Task created: task_id=...` が出力される | | |
| 36 | task_completed_handler Lambda ログ | `Task completed: task_id=...` が出力される | | |

## 14. CI/CD パイプライン確認

| # | 確認項目 | 確認方法 | 期待結果 | 結果 | 備考 |
|---|---------|---------|---------|------|------|
| 37 | CI — Lint | GitHub Actions ログ | `ruff check app/ tests/ lambda/` エラー 0 件 | | |
| 38 | CI — Test | GitHub Actions ログ | 46 tests passed（TC-01〜TC-39） | | |
| 39 | CI — Build | GitHub Actions ログ | `docker build` 成功 | | |
| 40 | CD — ECR Push | GitHub Actions ログ | `sample-cicd-dev` リポジトリへ push 成功 | | |
| 41 | CD — ECS Deploy | GitHub Actions ログ | `sample-cicd-dev` サービスへデプロイ完了 | | |
| 42 | CD — Lambda Deploy | GitHub Actions ログ | `sample-cicd-dev-task-*-handler` 3 関数の update-function-code 成功 | | |

## 15. 確認結果サマリ

| カテゴリ | 合計 | PASS | FAIL | 合格率 |
|---------|------|------|------|--------|
| v4 インフラ破棄 (#1-3) | 3 | | | |
| Workspace 作成・適用 (#4-8) | 5 | | | |
| S3 バケット (#9-12) | 4 | | | |
| CloudFront (#13-15) | 3 | | | |
| Workspace 命名 (#16-22) | 7 | | | |
| 基本 API (#23-24) | 2 | | | |
| Presigned URL アップロード (#25-27) | 3 | | | |
| CloudFront ダウンロード (#28-30) | 3 | | | |
| 添付ファイル削除 (#31-32) | 2 | | | |
| タスク削除時 S3 一括削除 (#33-34) | 2 | | | |
| SQS/EventBridge (#35-36) | 2 | | | |
| CI/CD (#37-42) | 6 | | | |
| **合計** | **42** | | | |

## 16. 判定

- ☐ **合格** — 全 42 項目が PASS
- ☐ **条件付き合格**
- ☐ **不合格**

### 判定者コメント

(実施時に記入)

### 検出された問題と対応

| # | 問題 | 原因 | 対応 |
|---|------|------|------|
| | | | |

## 17. クリーンアップ記録

| # | 作業項目 | 実施日 | 結果 | 備考 |
|---|---------|--------|------|------|
| 1 | S3 オブジェクト全削除 | | ☐ | `aws s3 rm s3://sample-cicd-dev-attachments --recursive` |
| 2 | ECR イメージ削除 | | ☐ | |
| 3 | SQS パージ | | ☐ | |
| 4 | Lambda Layer 削除 | | ☐ | |
| 5 | `terraform destroy -var-file=dev.tfvars` 実行 | | ☐ | |
| 6 | IAM ポリシー（lambda-deploy）削除 | | ☐ | |
