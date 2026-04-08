# デプロイ手順書 v9 — CI/CD 完全自動化 + セキュリティスキャン

## 概要

v9 では以下をデプロイする:
- CodeDeploy Blue/Green デプロイ基盤
- OIDC 認証（GitHub Actions → AWS）
- CI/CD ワークフロー分割（ci.yml + cd.yml）
- セキュリティスキャン（Trivy, tfsec）
- Terraform CI/CD（plan PR コメント + apply 自動実行）
- Infracost（PR コスト影響表示）
- GitHub Environments（dev / prod）

## 前提条件

- v8 インフラが稼働中であること
- Infracost アカウント登録 + API キー取得済み
- GitHub リポジトリの Settings へのアクセス権限

## 手順

### Step 1: Terraform ファイル変更

1. `infra/codedeploy.tf` — CodeDeploy App + Deployment Group（新規）
2. `infra/oidc.tf` — OIDC Provider + GitHub Actions IAM Role（新規）
3. `infra/alb.tf` — Blue/Green Target Group に変更
4. `infra/ecs.tf` — `deployment_controller = CODE_DEPLOY` に変更
5. `infra/iam.tf` — CodeDeploy サービスロール追加
6. `infra/variables.tf` — `github_repo`, `codedeploy_traffic_routing`, `enable_test_listener` 追加
7. `infra/dev.tfvars` / `prod.tfvars` — 新変数の値追加

### Step 2: ECS サービス再作成

`deployment_controller` は作成後に変更不可のため、ECS サービスを再作成する:

```bash
# 1. State からリソースを除外
terraform state rm aws_appautoscaling_policy.ecs_cpu
terraform state rm aws_appautoscaling_target.ecs_service
terraform state rm aws_ecs_service.app
terraform state rm aws_lb_target_group.app

# 2. 既存 ECS サービスを削除
aws ecs update-service --cluster sample-cicd-dev --service sample-cicd-dev --desired-count 0
aws ecs delete-service --cluster sample-cicd-dev --service sample-cicd-dev --force
# → INACTIVE になるまで待機

# 3. リスナーの Target Group を新 Blue TG に切り替え
aws elbv2 modify-listener --listener-arn <LISTENER_ARN> \
  --default-actions Type=forward,TargetGroupArn=<BLUE_TG_ARN>

# 4. 旧 Target Group を削除
aws elbv2 delete-target-group --target-group-arn <OLD_TG_ARN>

# 5. Terraform Apply（dev.tfvars に実値を設定してから）
terraform apply -var-file=dev.tfvars
```

### Step 3: GitHub 設定

**Secrets（Settings → Secrets and variables → Actions → Secrets）:**

| Secret 名 | 内容 |
|-----------|------|
| `AWS_OIDC_ROLE_ARN` | OIDC IAM ロール ARN（`terraform output` で確認） |
| `INFRACOST_API_KEY` | Infracost Cloud API キー |
| `HOSTED_ZONE_ID` | Route 53 Hosted Zone ID |
| `PSYCOPG2_LAYER_ARN` | Lambda Layer ARN |

**Environments（Settings → Environments）:**

| 環境名 | Protection Rules |
|--------|-----------------|
| `dev` | なし |
| `prod` | Required Reviewers: 1名 |

### Step 4: ワークフロー切り替え

1. `.github/workflows/ci-cd.yml` を削除
2. `.github/workflows/ci.yml` + `.github/workflows/cd.yml` を作成
3. `.trivyignore` を作成（ベースイメージ由来の脆弱性を除外）
4. コミット・プッシュ → CI → CD が自動実行

### Step 5: Access Key 廃止

CI/CD が OIDC で正常動作することを確認後:
1. GitHub Secrets から `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` を削除
2. IAM ユーザーの Access Key を無効化（オプション）

## トラブルシューティング

| 問題 | 原因 | 対処 |
|------|------|------|
| `Unable to Start a service that is still Draining` | ECS サービス削除後にまだ Draining 中 | `--force` で削除し、INACTIVE になるまで待機 |
| `target group does not have an associated load balancer` | 新 TG がリスナーに未紐付 | リスナーの default_action を新 Blue TG に切り替え |
| Trivy で CI 失敗 | ベースイメージ由来の脆弱性 | `.trivyignore` に CVE を追加 |
| terraform apply で `no matching Route 53 Hosted Zone` | tfvars にダミー値 | GitHub Secrets で `-var` 注入 |
| terraform apply で `AccessDeniedException: scheduler:*` | OIDC ロールの権限不足 | `oidc.tf` に `scheduler:*` を追加 |
