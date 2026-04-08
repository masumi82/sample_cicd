# デプロイ手順書 v10 — API Gateway + ElastiCache Redis + レート制限

## 概要

v10 では以下をデプロイする:
- API Gateway REST API（REGIONAL エンドポイント、ステージキャッシュ、Usage Plan、API キー）
- ElastiCache Redis（cache.t3.micro、プライベートサブネット）
- CloudFront オリジン変更（ALB → API Gateway）
- アプリケーションレベルキャッシュ（cache-aside パターン）
- モニタリング拡張（Dashboard 2 行 + Alarm 4 件）

## 前提条件

- v9 インフラが稼働中であること
- `terraform workspace select dev` で dev 環境が選択済み
- OIDC 認証が正常動作していること

## 手順

### Step 1: Terraform ファイル確認

以下のファイルが追加・変更されていることを確認:

| ファイル | 種別 |
|----------|------|
| `infra/apigateway.tf` | 新規 |
| `infra/elasticache.tf` | 新規 |
| `infra/security_groups.tf` | 変更 |
| `infra/variables.tf` | 変更 |
| `infra/dev.tfvars` | 変更 |
| `infra/prod.tfvars` | 変更 |
| `infra/ecs.tf` | 変更 |
| `infra/webui.tf` | 変更 |
| `infra/monitoring.tf` | 変更 |
| `infra/outputs.tf` | 変更 |
| `infra/iam.tf` | 変更 |

### Step 2: Terraform Plan

```bash
cd infra
terraform workspace select dev
terraform plan -var-file=dev.tfvars
```

**期待される出力**: Plan: ~20 to add, ~3 to change, 0 to destroy

主な追加リソース:
- `aws_api_gateway_rest_api.main`
- `aws_api_gateway_resource.tasks` / `tasks_proxy`
- `aws_api_gateway_method.tasks` / `tasks_proxy`
- `aws_api_gateway_integration.tasks` / `tasks_proxy`
- `aws_api_gateway_deployment.main`
- `aws_api_gateway_stage.main`（キャッシュクラスタ含む）
- `aws_api_gateway_usage_plan.main`
- `aws_api_gateway_api_key.main`
- `aws_elasticache_cluster.main`
- `aws_elasticache_subnet_group.main`
- `aws_security_group.redis`
- `aws_iam_role.apigateway_cloudwatch`
- CloudWatch Alarm x 4

主な変更リソース:
- `aws_cloudfront_distribution.webui`（Origin ALB → API Gateway）
- `aws_ecs_task_definition.app`（REDIS_URL 環境変数追加）
- `aws_cloudwatch_dashboard.main`（Row 6-7 追加）

### Step 3: Terraform Apply

```bash
terraform apply -var-file=dev.tfvars
```

> **注**: ElastiCache クラスタの作成に 5〜15 分かかる場合がある。API Gateway ステージキャッシュの作成にも数分かかる。

### Step 4: デプロイ結果確認

```bash
# API Gateway の Invoke URL を確認
terraform output api_gateway_invoke_url

# API Key を確認（sensitive）
terraform output -raw api_gateway_api_key

# Redis エンドポイントを確認
terraform output redis_endpoint
```

### Step 5: アプリケーションデプロイ

ECS タスク定義に `REDIS_URL` が追加されているため、次回の CD パイプライン実行（または手動デプロイ）で反映される。

```bash
# 手動でタスク定義を更新する場合
# CD パイプラインが次回 main push 時に自動的に新タスク定義でデプロイ
git push origin main
```

### Step 6: 動作確認

#### 6.1 API Gateway 直接アクセス

```bash
# API Gateway Invoke URL 経由でアクセス（API キー必須）
APIGW_URL=$(terraform output -raw api_gateway_invoke_url)
API_KEY=$(terraform output -raw api_gateway_api_key)

# API キー付きリクエスト → 200 OK
curl -s "${APIGW_URL}/tasks" -H "x-api-key: ${API_KEY}" | jq

# API キーなしリクエスト → 403 Forbidden
curl -s "${APIGW_URL}/tasks" -w "\n%{http_code}\n"
```

#### 6.2 CloudFront 経由アクセス

```bash
# CloudFront 経由（API キーは custom_header で自動注入）
APP_URL=$(terraform output -raw app_url)

curl -s "${APP_URL}/tasks" | jq
```

#### 6.3 キャッシュ動作確認

```bash
# タスク作成
curl -s -X POST "${APP_URL}/tasks" \
  -H "Content-Type: application/json" \
  -d '{"title":"Cache Test"}' | jq

# タスク一覧取得（1 回目: キャッシュミス → DB アクセス）
curl -s "${APP_URL}/tasks" | jq

# タスク一覧取得（2 回目: キャッシュヒット → Redis から応答）
curl -s "${APP_URL}/tasks" | jq

# CloudWatch メトリクスで CacheHits / CacheMisses を確認
```

#### 6.4 Usage Plan 確認

```bash
# API キーなしで直接 API Gateway にアクセス → 403
curl -s "${APIGW_URL}/tasks" -w "\n%{http_code}\n"
# 期待: 403
```

## トラブルシューティング

### ElastiCache 接続エラー

ECS タスクから Redis に接続できない場合:
1. セキュリティグループを確認（ECS Tasks SG → Redis SG:6379）
2. サブネット間のルーティングを確認（VPC ルートテーブル）
3. `REDIS_URL` 環境変数がタスク定義に正しく設定されているか確認

### API Gateway 500 エラー

API Gateway から ALB への HTTP プロキシ統合でエラーが出る場合:
1. ALB が正常動作しているか確認
2. API Gateway の統合 URL が正しいか確認
3. CloudWatch Logs の API Gateway アクセスログを確認

### CloudFront から API Gateway への接続エラー

1. CloudFront のオリジンドメインが正しいか確認
2. `origin_protocol_policy = "https-only"` が設定されているか確認
3. `x-api-key` custom_header が正しく設定されているか確認

## コスト影響

| 項目 | 月額 |
|------|------|
| API Gateway ステージキャッシュ (0.5 GB) | ~$14 |
| ElastiCache Redis (cache.t3.micro) | ~$13 |
| その他（ログ等） | <$1 |
| **合計追加コスト** | **~$28/月** |
