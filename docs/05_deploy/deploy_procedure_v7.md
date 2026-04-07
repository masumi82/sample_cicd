# デプロイ手順書 (v7)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-07 |
| バージョン | 7.0 |
| 前バージョン | [deploy_procedure_v6.md](deploy_procedure_v6.md) (v6.0) |

## 変更概要

v6 のデプロイ手順に対して以下の変更・追加を行う:

| # | 変更点 | 説明 |
|---|--------|------|
| 1 | Cognito User Pool 追加 | `cognito.tf` — User Pool + App Client（email ログイン、SRP 認証） |
| 2 | WAF v2 WebACL 追加 | `waf.tf` — マネージドルール 2 つ + レートリミット（us-east-1） |
| 3 | JWT 認証ミドルウェア追加 | `app/auth.py` — Cognito JWKS による JWT 検証 |
| 4 | API エンドポイント保護 | `/tasks*` に `Depends(get_current_user)` 追加 |
| 5 | React ログイン画面追加 | `frontend/src/auth/` — Login / Signup / ConfirmSignup / PrivateRoute |
| 6 | CI/CD config.js 更新 | Cognito User Pool ID + App Client ID を動的注入 |
| 7 | CloudFront に WAF 関連付け | `webui.tf` に `web_acl_id` 追加 |

> **重要**: v6 インフラは Terraform Workspace `dev` で稼働中。`terraform destroy` は不要。
> `terraform apply` で差分リソースのみ追加する。

## 1. 前提条件

| 項目 | 要件 |
|------|------|
| AWS CLI v2 | インストール・設定済み |
| Terraform | インストール済み |
| Node.js 20 | インストール済み |
| v6 インフラ | `terraform apply` 済み（Workspace: dev） |
| GitHub Actions シークレット | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` |

## 2. v7 コードのコミット・プッシュ

```bash
cd ~/sample_cicd

git add \
  app/auth.py \
  app/requirements.txt \
  app/routers/tasks.py \
  app/routers/attachments.py \
  tests/conftest.py \
  tests/test_auth.py \
  docs/01_requirements/requirements_v7.md \
  docs/02_design/architecture_v7.md \
  docs/02_design/infrastructure_v7.md \
  docs/02_design/cicd_v7.md \
  docs/04_test/test_plan_v7.md \
  docs/05_deploy/deploy_procedure_v7.md \
  docs/05_deploy/verification_v7.md \
  infra/cognito.tf \
  infra/waf.tf \
  infra/main.tf \
  infra/ecs.tf \
  infra/webui.tf \
  infra/variables.tf \
  infra/outputs.tf \
  infra/dev.tfvars \
  infra/prod.tfvars \
  .github/workflows/ci-cd.yml \
  CLAUDE.md \
  frontend/

git commit -m "v7: Security + Authentication (Cognito, JWT, WAF)"

git push origin main
```

> **CI/CD 自動実行**: push により GitHub Actions が起動し、以下が自動実行される:
> - CI: ruff lint → pytest (62 tests) → docker build → npm build
> - CD: ECR push → ECS deploy → Lambda 更新 → フロントエンド S3 sync (config.js に Cognito 設定注入) + CloudFront invalidation

## 3. Terraform apply（新規リソース追加）

### 3.1 terraform init（us-east-1 プロバイダ追加のため必要）

```bash
cd ~/sample_cicd/infra
terraform workspace select dev
terraform init
```

> v7 で `provider "aws" { alias = "us_east_1" }` を追加したため、`terraform init` が必要。

### 3.2 plan の確認

```bash
terraform plan -var-file=dev.tfvars
```

期待される出力例（追加される主なリソース）:

```
+ aws_cognito_user_pool.main
+ aws_cognito_user_pool_client.spa
+ aws_wafv2_web_acl.cloudfront
```

変更されるリソース:
```
~ aws_cloudfront_distribution.webui (web_acl_id 追加)
~ aws_ecs_task_definition.app (COGNITO 環境変数追加)
```

### 3.3 apply の実行

```bash
terraform apply -var-file=dev.tfvars
```

`Enter a value:` に `yes` を入力。

期待される出力:

```
Apply complete! Resources: 3 added, 2 changed, 0 destroyed.

Outputs:
  cognito_user_pool_id = "ap-northeast-1_XXXXXXXXX"
  cognito_app_client_id = "xxxxxxxxxxxxxxxxxxxxxxxxxx"
  waf_web_acl_arn = "arn:aws:wafv2:us-east-1:..."
```

### 3.4 output の確認

```bash
terraform output cognito_user_pool_id
terraform output cognito_app_client_id
terraform output waf_web_acl_arn
```

## 4. GitHub Actions シークレットの確認

v7 では追加シークレット不要。CI/CD ワークフロー内で Cognito 設定を動的取得。

確認コマンド:

```bash
gh secret list
```

期待されるシークレット:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

> **追加 IAM 権限**: GitHub Actions の IAM ユーザーに以下の権限を追加する:
> - `cognito-idp:ListUserPools`
> - `cognito-idp:ListUserPoolClients`

```bash
# IAM ポリシー追加例
aws iam put-user-policy \
  --user-name github-actions-sample-cicd \
  --policy-name v7-cognito-permissions \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": [
        "cognito-idp:ListUserPools",
        "cognito-idp:ListUserPoolClients"
      ],
      "Resource": "*"
    }]
  }'
```

## 5. CI/CD パイプラインの確認

### 5.1 ワークフローの実行確認

```bash
gh run list --limit 5
gh run view --log
```

### 5.2 config.js にCognito 設定が注入されていることを確認

CD ステップで以下が実行されることを確認:

1. **Cognito User Pool ID 取得** — `aws cognito-idp list-user-pools`
2. **App Client ID 取得** — `aws cognito-idp list-user-pool-clients`
3. **config.js 生成** — `API_URL`, `COGNITO_USER_POOL_ID`, `COGNITO_APP_CLIENT_ID`
4. **S3 sync** — `aws s3 sync frontend/dist/ s3://sample-cicd-dev-webui --delete`
5. **CloudFront invalidation** — `aws cloudfront create-invalidation --paths "/*"`

## 6. 動作確認

### 6.1 Cognito User Pool 確認

```bash
aws cognito-idp list-user-pools --max-results 10 \
  --query "UserPools[?Name=='sample-cicd-dev-users']" \
  --region ap-northeast-1
```

### 6.2 WAF WebACL 確認

```bash
aws wafv2 list-web-acls --scope CLOUDFRONT --region us-east-1 \
  --query "WebACLs[?Name=='sample-cicd-dev-webui-waf']"
```

### 6.3 未認証 API アクセス確認

```bash
# CloudFront ドメイン名の確認
CF_DOMAIN=$(cd ~/sample_cicd/infra && terraform output -raw webui_cloudfront_domain_name)

# 認証なしで API を叩く → 401 が返ることを確認
curl -s -o /dev/null -w "%{http_code}" "https://${CF_DOMAIN}/tasks"
# 期待: 401
```

### 6.4 Web UI ログイン確認

ブラウザで `https://<cloudfront_domain>` にアクセスし:

1. ログイン画面が表示されることを確認
2. 「Sign up」からアカウント作成
3. メールで確認コードを受信
4. 確認コードを入力してアカウント有効化
5. ログインしてタスク一覧画面が表示されることを確認
6. タスクの作成・編集・削除・完了切替が動作することを確認

### 6.5 WAF 確認

AWS コンソール → WAF & Shield → Web ACLs (us-east-1 リージョン) で:
- `sample-cicd-dev-webui-waf` が存在することを確認
- CloudFront ディストリビューションに関連付けられていることを確認
- サンプルリクエストが表示されることを確認

## 7. ロールバック手順

### 7.1 アプリケーションのロールバック

認証を無効化する場合、ECS タスク定義から `COGNITO_USER_POOL_ID` と `COGNITO_APP_CLIENT_ID` を削除するか、空文字列に設定する。Graceful degradation により認証がスキップされる。

### 7.2 Terraform リソースのロールバック

```bash
cd ~/sample_cicd/infra
terraform destroy -target=aws_cognito_user_pool.main -var-file=dev.tfvars
terraform destroy -target=aws_wafv2_web_acl.cloudfront -var-file=dev.tfvars
```

> WAF を削除する場合は先に CloudFront の `web_acl_id` を解除する必要がある。
