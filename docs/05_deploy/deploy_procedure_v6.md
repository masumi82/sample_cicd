# デプロイ手順書 (v6)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-07 |
| バージョン | 6.0 |
| 前バージョン | [deploy_procedure_v5.md](deploy_procedure_v5.md) (v5.0) |

## 変更概要

v5 のデプロイ手順に対して以下の変更・追加を行う:

| # | 変更点 | 説明 |
|---|--------|------|
| 1 | 構造化ログ追加 | FastAPI + Lambda 全関数が JSON 形式でログ出力。CloudWatch Logs Insights 対応 |
| 2 | X-Ray SDK + サイドカー追加 | ECS に X-Ray daemon サイドカーコンテナ追加。Lambda は Active tracing 有効化 |
| 3 | CORSMiddleware 追加 | `CORS_ALLOWED_ORIGINS` 環境変数で許可オリジンを制御 |
| 4 | CloudWatch Dashboard 追加 | `monitoring.tf` — ALB/ECS/RDS/Lambda/SQS の 12 ウィジェット |
| 5 | CloudWatch Alarms 追加 | 12 アラーム (ALB/ECS/RDS/Lambda/SQS DLQ) + SNS 通知連携 |
| 6 | SNS Topic 追加 | `sns.tf` — アラーム通知先。`alarm_email` 変数でメール購読設定 |
| 7 | Web UI S3 バケット追加 | `webui.tf` — React SPA ホスティング用バケット (OAC, パブリックアクセスブロック) |
| 8 | Web UI CloudFront 追加 | `webui.tf` — SPA フォールバック (403/404 → index.html)、OAC 経由 |
| 9 | ECS タスク定義変更 | CPU 512 / Memory 1024 へ引き上げ。X-Ray daemon サイドカー追加 |
| 10 | React SPA 追加 | `frontend/` — Vite + React + Tailwind CSS でタスク管理 UI |
| 11 | CI/CD フロントエンド対応 | Node.js セットアップ + npm build + S3 sync + CloudFront invalidation |

> **重要**: v5 インフラは Terraform Workspace `dev` で稼働中。`terraform destroy` は不要。
> `terraform apply` で差分リソースのみ追加する（既存リソースへの影響を最小化）。

## 1. 前提条件

| 項目 | 要件 |
|------|------|
| AWS CLI v2 | インストール・設定済み |
| Terraform | インストール済み |
| Node.js 20 | インストール済み（`node --version` で確認） |
| npm | Node.js に同梱 |
| v5 インフラ | `terraform apply` 済み（Workspace: dev） |
| GitHub Actions シークレット | `AWS_ACCOUNT_ID`, `AWS_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` |

### Node.js インストール（未インストールの場合）

```bash
# nvm 経由でインストール
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
source ~/.bashrc
nvm install 20
nvm use 20
node --version  # v20.x.x
```

## 2. v6 コードのコミット・プッシュ

v6 の変更を git にコミットして main ブランチにプッシュする。

```bash
cd ~/sample_cicd

# v6 変更ファイルを全てステージング
git add \
  app/logging_config.py \
  app/main.py \
  app/requirements.txt \
  lambda/task_created_handler.py \
  lambda/task_completed_handler.py \
  lambda/task_cleanup_handler.py \
  tests/test_observability.py \
  docs/04_test/test_plan_v6.md \
  docs/05_deploy/deploy_procedure_v6.md \
  docs/05_deploy/verification_v6.md \
  infra/monitoring.tf \
  infra/sns.tf \
  infra/webui.tf \
  infra/ecs.tf \
  infra/iam.tf \
  infra/lambda.tf \
  infra/logs.tf \
  infra/outputs.tf \
  infra/variables.tf \
  infra/dev.tfvars \
  infra/prod.tfvars \
  .github/workflows/ci-cd.yml \
  .gitignore \
  frontend/

git commit -m "v6: Observability + Web UI (CloudWatch, X-Ray, SNS, React SPA)"

git push origin main
```

> **CI/CD 自動実行**: push により GitHub Actions が起動し、以下が自動実行される:
> - CI: ruff lint → pytest → docker build → npm build
> - CD: ECR push → ECS deploy → Lambda 更新 → フロントエンド S3 sync + CloudFront invalidation

## 3. Terraform apply（新規リソース追加）

### 3.1 plan の確認

```bash
cd ~/sample_cicd/infra
terraform workspace select dev
terraform plan -var-file=dev.tfvars
```

期待される出力例（追加される主なリソース）:

```
+ aws_cloudwatch_dashboard.main
+ aws_cloudwatch_metric_alarm.alb_5xx
+ aws_cloudwatch_metric_alarm.alb_unhealthy_hosts
+ aws_cloudwatch_metric_alarm.alb_high_latency
+ aws_cloudwatch_metric_alarm.ecs_cpu_high
+ aws_cloudwatch_metric_alarm.ecs_memory_high
+ aws_cloudwatch_metric_alarm.rds_cpu_high
+ aws_cloudwatch_metric_alarm.rds_free_storage_low
+ aws_cloudwatch_metric_alarm.rds_connections_high
+ aws_cloudwatch_metric_alarm.lambda_errors
+ aws_cloudwatch_metric_alarm.lambda_throttles
+ aws_cloudwatch_metric_alarm.lambda_duration_high
+ aws_cloudwatch_metric_alarm.sqs_dlq_messages
+ aws_sns_topic.alarm_notifications
+ aws_s3_bucket.webui
+ aws_s3_bucket_policy.webui
+ aws_s3_bucket_public_access_block.webui
+ aws_cloudfront_origin_access_control.webui
+ aws_cloudfront_distribution.webui
+ aws_cloudwatch_log_group.xray
```

変更されるリソース（ECS タスク定義、IAM ロール、Lambda）も確認する。

### 3.2 apply の実行

```bash
terraform apply -var-file=dev.tfvars
```

`Enter a value:` に `yes` を入力。完了まで約 5〜10 分（CloudFront ディストリビューションのデプロイに時間がかかる場合あり）。

期待される出力:

```
Apply complete! Resources: XX added, X changed, 0 destroyed.

Outputs:
  dashboard_url = "https://ap-northeast-1.console.aws.amazon.com/cloudwatch/home?region=ap-northeast-1#dashboards:name=sample-cicd-dev"
  webui_cloudfront_domain_name = "d****.cloudfront.net"
  webui_cloudfront_distribution_id = "E**************"
  webui_bucket_name = "sample-cicd-dev-webui"
  sns_topic_arn = "arn:aws:sns:ap-northeast-1:XXXX:sample-cicd-dev-alarm-notifications"
```

### 3.3 output の確認

```bash
terraform output
```

`webui_cloudfront_domain_name` と `webui_cloudfront_distribution_id` を控えておく（GitHub Actions シークレット不要。CI/CD ステップで動的取得）。

## 4. GitHub Actions シークレットの確認

既存シークレットに加えて、v6 では追加シークレット不要。
CI/CD ワークフロー内で ALB DNS と CloudFront Distribution ID を動的取得している。

確認コマンド（既存シークレット一覧）:

```bash
gh secret list
```

期待されるシークレット:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

> `AWS_REGION` はワークフロー内で `ap-northeast-1` にハードコード済み。
> ECR レジストリは `amazon-ecr-login` アクションが動的に取得するため `AWS_ACCOUNT_ID` も不要。

## 5. CI/CD パイプラインの確認

### 5.1 ワークフローの実行確認

```bash
# 最新の実行状況確認
gh run list --limit 5

# 最新実行の詳細ログ
gh run view --log
```

### 5.2 フロントエンドデプロイ確認

CD ステップで以下が実行されることを確認:

1. **Node.js セットアップ** — actions/setup-node@v4, Node.js 20
2. **フロントエンドビルド** — `cd frontend && npm ci && npm run build`
3. **API URL 注入** — `dist/config.js` に ALB DNS を書き込み
4. **S3 sync** — `aws s3 sync frontend/dist/ s3://sample-cicd-dev-webui --delete`
5. **CloudFront invalidation** — `aws cloudfront create-invalidation --paths "/*"`

## 6. 動作確認

### 6.1 Web UI アクセス確認

```bash
# CloudFront ドメイン名の確認
cd ~/sample_cicd/infra
terraform output webui_cloudfront_domain_name
```

ブラウザで `https://<webui_cloudfront_domain_name>` にアクセスし、タスク一覧画面が表示されることを確認する。

### 6.2 構造化ログ確認

```bash
# ECS ログをJSON形式で確認
aws logs filter-log-events \
  --log-group-name /ecs/sample-cicd-dev \
  --limit 5 \
  --region ap-northeast-1 \
  --query 'events[*].message' \
  --output text | head -5
```

JSON 形式（`{"timestamp": "...", "level": "...", "logger": "...", "message": "..."}`）で出力されていることを確認。

### 6.3 X-Ray トレース確認

AWS コンソールから X-Ray > Service Map を開き、リクエストのトレースが記録されていることを確認する。

### 6.4 CloudWatch Dashboard 確認

```bash
# Dashboard URL の確認
cd ~/sample_cicd/infra
terraform output dashboard_url
```

出力された URL をブラウザで開き、各ウィジェット（ALB/ECS/RDS/Lambda/SQS）にメトリクスが表示されることを確認する。

### 6.5 CloudWatch Alarms 確認

```bash
aws cloudwatch describe-alarms \
  --alarm-name-prefix sample-cicd-dev \
  --query 'MetricAlarms[*].[AlarmName,StateValue]' \
  --output table \
  --region ap-northeast-1
```

大部分のアラームが `OK` または `INSUFFICIENT_DATA`（低負荷のため）状態であることを確認する。

## 7. ロールバック手順

### 7.1 フロントエンドのロールバック

前バージョンのビルド成果物を S3 に再アップロードし、CloudFront invalidation を実行する。

```bash
# 特定コミットの frontend ビルドを再実行して S3 にデプロイ
git checkout <previous-commit>
cd frontend && npm ci && npm run build

# config.js を現在の CloudFront ドメインで上書き
CF_DOMAIN=$(cd ~/sample_cicd/infra && terraform output -raw webui_cloudfront_domain_name)
echo "window.APP_CONFIG = { API_URL: 'https://${CF_DOMAIN}' };" > dist/config.js

aws s3 sync dist/ s3://sample-cicd-dev-webui --delete
DIST_ID=$(cd ~/sample_cicd/infra && terraform output -raw webui_cloudfront_distribution_id)
aws cloudfront create-invalidation --distribution-id ${DIST_ID} --paths "/*"
```

### 7.2 Terraform リソースのロールバック

新規追加リソース（Dashboard/Alarms/SNS/WebUI）を個別に削除したい場合:

```bash
cd ~/sample_cicd/infra
terraform destroy -target=aws_cloudwatch_dashboard.main -var-file=dev.tfvars
# など、対象リソースを指定して実行
```

> 全リソース破棄の場合は `terraform destroy -var-file=dev.tfvars` を実行する（v5 リソースも含む）。
