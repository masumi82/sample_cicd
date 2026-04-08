# デプロイ手順書 (v8)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-07 |
| バージョン | 8.0 |
| 前バージョン | [deploy_procedure_v7.md](deploy_procedure_v7.md) (v7.0) |

## 変更概要

v7 のデプロイ手順に対して以下の変更・追加を行う:

| # | 変更点 | 説明 |
|---|--------|------|
| 1 | Remote State 基盤追加 | `bootstrap/main.tf` — S3 バケット + DynamoDB テーブルで tfstate 管理 |
| 2 | Remote State 移行 | `main.tf` の backend "s3" ブロック有効化、ローカル state を S3 に移行 |
| 3 | ACM 証明書追加 | `custom_domain.tf` — ワイルドカード証明書（us-east-1、DNS 検証） |
| 4 | Route 53 ALIAS レコード追加 | `custom_domain.tf` — CloudFront へのカスタムドメインルーティング |
| 5 | CloudFront カスタムドメイン適用 | `webui.tf` — aliases + viewer_certificate を動的切替 |
| 6 | CI/CD config.js 更新 | `CUSTOM_DOMAIN_NAME` Variable で API_URL にカスタムドメインを注入 |

> **重要**: v7 インフラは Terraform Workspace `dev` で稼働中。`terraform destroy` は不要。
> `terraform apply` で差分リソースのみ追加する。

## 1. 前提条件

| 項目 | 要件 |
|------|------|
| AWS CLI v2 | インストール・設定済み |
| Terraform | インストール済み |
| Node.js 20 | インストール済み |
| v7 インフラ | `terraform apply` 済み（Workspace: dev） |
| Route 53 ドメイン | `sample-cicd.click` が購入・登録済み |
| GitHub Actions シークレット | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` |

## 2. Bootstrap（Remote State 基盤）

### 2.1 bootstrap ディレクトリの apply

```bash
cd ~/sample_cicd/infra/bootstrap
terraform init
terraform apply
```

`Enter a value:` に `yes` を入力。

期待される出力:

```
Apply complete! Resources: 5 added, 0 destroyed.

Outputs:
  dynamodb_table_name = "sample-cicd-tflock"
  s3_bucket_name = "sample-cicd-tfstate"
```

### 2.2 作成リソースの確認

```bash
aws s3 ls | grep sample-cicd-tfstate
aws dynamodb describe-table --table-name sample-cicd-tflock \
  --query "Table.TableName" --output text
```

## 3. Remote State 移行

### 3.1 backend "s3" ブロックの有効化

`infra/main.tf` の backend "s3" ブロックがコメントアウトされている場合はコメント解除する:

```hcl
terraform {
  backend "s3" {
    bucket         = "sample-cicd-tfstate"
    key            = "terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "sample-cicd-tflock"
    encrypt        = true
  }
  # ...
}
```

### 3.2 ローカル state を S3 に移行

```bash
cd ~/sample_cicd/infra
terraform init -migrate-state -force-copy
```

期待される出力:

```
Successfully configured the backend "s3"!
```

### 3.3 dev workspace 作成

```bash
terraform workspace new dev
```

> **注意**: 既に dev workspace が存在する場合は `terraform workspace select dev` を使用する。

### 3.4 state 移行の確認

```bash
aws s3 ls s3://sample-cicd-tfstate/env:/dev/ --recursive
```

state ファイルが S3 に保存されていることを確認する。

## 4. v8 コードのコミット・プッシュ

```bash
cd ~/sample_cicd

git add \
  infra/bootstrap/ \
  infra/custom_domain.tf \
  infra/main.tf \
  infra/webui.tf \
  infra/variables.tf \
  infra/outputs.tf \
  infra/dev.tfvars \
  infra/prod.tfvars \
  infra/alb.tf \
  infra/security_groups.tf \
  .github/workflows/ci-cd.yml \
  docs/01_requirements/ \
  docs/02_design/ \
  docs/04_test/ \
  docs/05_deploy/deploy_procedure_v8.md \
  docs/05_deploy/verification_v8.md \
  CLAUDE.md

git commit -m "v8: HTTPS + Custom Domain + Remote State"

git push origin main
```

> **CI/CD 自動実行**: push により GitHub Actions が起動し、以下が自動実行される:
> - CI: ruff lint → pytest (62 tests) → docker build → npm build
> - CD: ECR push → ECS deploy → Lambda 更新 → フロントエンド S3 sync + CloudFront invalidation

## 5. Terraform apply（新規リソース追加）

### 5.1 terraform init

```bash
cd ~/sample_cicd/infra
terraform workspace select dev
terraform init
```

### 5.2 plan の確認

```bash
terraform plan -var-file=dev.tfvars
```

期待される出力例（追加される主なリソース）:

```
+ aws_acm_certificate.cloudfront[0]
+ aws_acm_certificate_validation.cloudfront[0]
+ aws_route53_record.cert_validation["*.sample-cicd.click"]
+ aws_route53_record.cert_validation["sample-cicd.click"]
+ aws_route53_record.webui[0]
```

変更されるリソース:
```
~ aws_cloudfront_distribution.webui (aliases + viewer_certificate 変更)
```

### 5.3 apply の実行

```bash
terraform apply -var-file=dev.tfvars
```

`Enter a value:` に `yes` を入力。

> **注意**: ACM 証明書の DNS 検証に数分かかる場合がある。`aws_acm_certificate_validation` リソースが
> 検証完了まで待機するため、apply 全体で 5〜10 分程度かかることがある。

期待される出力:

```
Apply complete! Resources: 5 added, 1 changed, 0 destroyed.

Outputs:
  app_url = "https://dev.sample-cicd.click"
  custom_domain_url = "https://dev.sample-cicd.click"
```

### 5.4 output の確認

```bash
terraform output app_url
terraform output custom_domain_url
```

## 6. GitHub Actions Variables 追加

### 6.1 Repository Variable の設定

```bash
gh variable set CUSTOM_DOMAIN_NAME --body "dev.sample-cicd.click"
```

> **目的**: CI/CD の config.js 生成ステップで `CUSTOM_DOMAIN_NAME` が設定されている場合、
> API_URL にカスタムドメインを使用する。未設定の場合は CloudFront ドメインにフォールバックする。

### 6.2 設定確認

```bash
gh variable list
```

期待される出力:

```
CUSTOM_DOMAIN_NAME  dev.sample-cicd.click  ...
```

## 7. CI/CD 再実行（config.js にカスタムドメイン注入）

Step 4 の push 時点では `CUSTOM_DOMAIN_NAME` が未設定のため、config.js に CloudFront ドメインが設定されている。
Variable 追加後に CI/CD を再実行して config.js を更新する。

```bash
# 最新の run を再実行
gh run rerun $(gh run list --limit 1 --json databaseId --jq '.[0].databaseId')
```

または空コミットで再実行:

```bash
cd ~/sample_cicd
git commit --allow-empty -m "ci: trigger config.js update with custom domain"
git push origin main
```

## 8. 動作確認

### 8.1 ACM 証明書確認

```bash
aws acm list-certificates --region us-east-1 \
  --query "CertificateSummaryList[?DomainName=='*.sample-cicd.click'].[DomainName,Status]" \
  --output table
```

期待: Status が `ISSUED` であること。

### 8.2 Route 53 レコード確認

```bash
aws route53 list-resource-record-sets \
  --hosted-zone-id ZXXXXXXXXXXXXXXXXXXXX \
  --query "ResourceRecordSets[?Name=='dev.sample-cicd.click.']"
```

> **注意**: Hosted Zone ID はダミー値に置換。実際の値を使用すること。

### 8.3 HTTPS アクセス確認

```bash
# カスタムドメインでアクセス
curl -s -o /dev/null -w "%{http_code}" "https://dev.sample-cicd.click"
# 期待: 200

# SSL 証明書の確認
curl -vI "https://dev.sample-cicd.click" 2>&1 | grep "subject:"
# 期待: *.sample-cicd.click が含まれる
```

### 8.4 未認証 API アクセス確認

```bash
curl -s -o /dev/null -w "%{http_code}" "https://dev.sample-cicd.click/tasks"
# 期待: 401
```

### 8.5 Web UI ログイン確認

ブラウザで `https://dev.sample-cicd.click` にアクセスし:

1. ログイン画面が表示されることを確認
2. ログインしてタスク一覧画面が表示されることを確認
3. タスクの作成が動作することを確認
4. ログアウトが動作することを確認

### 8.6 config.js 確認

```bash
aws s3 cp s3://sample-cicd-dev-webui/config.js - 2>/dev/null
```

期待: `API_URL` に `dev.sample-cicd.click` が含まれること。

## 9. ロールバック手順

### 9.1 カスタムドメイン無効化

`dev.tfvars` で `enable_custom_domain = false` に変更して apply:

```bash
cd ~/sample_cicd/infra
# dev.tfvars を編集: enable_custom_domain = false
terraform apply -var-file=dev.tfvars
```

> カスタムドメイン関連リソース（ACM 証明書、Route 53 レコード）が削除され、
> CloudFront は CloudFront ドメイン名のみでアクセス可能に戻る。

### 9.2 Remote State からローカルへの戻し

```bash
cd ~/sample_cicd/infra
# main.tf の backend "s3" ブロックをコメントアウト
terraform init -migrate-state -force-copy
```

### 9.3 GitHub Actions Variable 削除

```bash
gh variable delete CUSTOM_DOMAIN_NAME
```
