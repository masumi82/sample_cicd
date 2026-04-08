---
name: deploy
description: "One-command deploy workflow. Handles tfvars real values, terraform apply, git push (with masked values), CI/CD wait, and verification. Usage: /deploy dev"
user-invocable: true
---

# Deploy

ワンコマンドでデプロイを実行する。引数で環境を指定（`dev` or `prod`）。

```
/deploy dev   → dev 環境にデプロイ
/deploy prod  → prod 環境にデプロイ（確認プロンプト付き）
```

デフォルト（引数なし）: `dev`

All output must be in Japanese.

## デプロイフロー

### Step 1: 事前チェック
- `ruff check app/ tests/ lambda/` — Lint
- `DATABASE_URL=sqlite:// pytest tests/ -v` — テスト
- `cd infra && terraform validate` — Terraform 構文検証
- 失敗した場合はデプロイを中止

### Step 2: tfvars の実値設定
- `infra/dev.tfvars`（or `prod.tfvars`）のダミー値を実値に置換:
  - `hosted_zone_id`: `Z0XXXXXXXXXXXXXXXXXX` → 実際の Hosted Zone ID
  - `psycopg2_layer_arn`: `123456789012` → 実際のアカウント ID
- 実値は `terraform output` や AWS CLI で取得

### Step 3: Terraform apply
```bash
cd infra
terraform workspace select $ENV
terraform plan -var-file=$ENV.tfvars
# ユーザーに plan 結果を表示し、確認を求める
terraform apply -var-file=$ENV.tfvars -auto-approve
```

### Step 4: セキュリティマスク + コミット・プッシュ
- tfvars のダミー値を戻す
- `/security-check` スキルと同等のチェックを実行
- `git add` → `git commit` → `git push`

### Step 5: CI/CD 待機
- `gh run watch` で CI/CD の完了を待機
- 失敗時はログを表示

### Step 6: 動作確認
- `curl` で API エンドポイント確認（`/`, `/health`, `/tasks`）
- カスタムドメインでのアクセス確認
- config.js の内容確認

### Step 7: 結果レポート
- 成功/失敗のサマリを表示
- terraform output の主要値を表示

## prod 環境の追加ガード

`prod` 指定時は以下の追加確認:
1. 「本番環境にデプロイします。よろしいですか？」と確認
2. `terraform plan` の結果を必ず表示
3. destroy されるリソースがある場合は警告
