# 動作確認記録 (v7)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-07 |
| バージョン | 7.0 |
| 前バージョン | [verification_v6.md](verification_v6.md) (v6.0) |

## 1. 確認概要

本ドキュメントは `deploy_procedure_v7.md` に従ってデプロイを実施した後の動作確認記録である。

v7 では以下の機能が追加される:
- **Cognito 認証**: User Pool + JWT ベースの API 保護
- **WAF**: CloudFront に WebACL 適用（マネージドルール + レートリミット）
- **React ログイン画面**: サインアップ / ログイン / ログアウト / 保護ルーティング

## 2. 環境情報

| 項目 | 値 |
|------|------|
| AWS アカウント ID | （セキュリティのため省略） |
| AWS リージョン | ap-northeast-1 |
| Terraform Workspace | dev |
| Cognito User Pool ID | (terraform output cognito_user_pool_id で確認) |
| Cognito App Client ID | (terraform output cognito_app_client_id で確認) |
| WAF WebACL ARN | (terraform output waf_web_acl_arn で確認) |
| Web UI CloudFront ドメイン名 | (terraform output webui_cloudfront_domain_name で確認) |
| 実施日 | |
| 実施者 | m-horiuchi |

## 3. コミット・プッシュ / CI パイプライン

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 1 | git commit 成功 | `git log --oneline -1` | v7 コミットが最新 | | |
| 2 | git push 成功 | `git push origin main` の出力 | エラーなし | | |
| 3 | CI: ruff lint PASS | `gh run view --log` | All checks passed | | |
| 4 | CI: pytest 62 件 PASS | `gh run view --log` | 62 passed | | |
| 5 | CI: docker build 成功 | `gh run view --log` | Build 成功 | | |
| 6 | CI: npm build 成功 | `gh run view --log` | ✓ built | | |

## 4. Terraform apply

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 7 | terraform init 成功 | `terraform init` | Initialized | | us-east-1 プロバイダ追加のため |
| 8 | terraform plan 確認 | `terraform plan -var-file=dev.tfvars` | Cognito + WAF が計画に含まれる | | |
| 9 | terraform apply 成功 | `terraform apply -var-file=dev.tfvars` | "Apply complete!" | | |
| 10 | Cognito User Pool 出力 | `terraform output cognito_user_pool_id` | ID が出力される | | |
| 11 | Cognito App Client 出力 | `terraform output cognito_app_client_id` | ID が出力される | | |
| 12 | WAF WebACL 出力 | `terraform output waf_web_acl_arn` | ARN が出力される | | |

## 5. Cognito User Pool 確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 13 | User Pool 存在確認 | `aws cognito-idp list-user-pools --max-results 10` | `sample-cicd-dev-users` が含まれる | | |
| 14 | App Client 存在確認 | `aws cognito-idp list-user-pool-clients --user-pool-id <pool_id>` | `sample-cicd-dev-spa` が含まれる | | |

## 6. WAF 確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 15 | WebACL 存在確認 | `aws wafv2 list-web-acls --scope CLOUDFRONT --region us-east-1` | `sample-cicd-dev-webui-waf` が含まれる | | |
| 16 | CloudFront 関連付け確認 | AWS コンソール → CloudFront → Distribution → WAF | WebACL が関連付けされている | | |

## 7. CD パイプライン確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 17 | CD: ECS デプロイ成功 | `gh run view --log` | Service updated | | |
| 18 | CD: Lambda 更新成功 | `gh run view --log` | 3 関数の更新成功 | | |
| 19 | CD: config.js に Cognito 設定含まれる | `aws s3 cp s3://sample-cicd-dev-webui/config.js -` | COGNITO_USER_POOL_ID が含まれる | | |
| 20 | CD: CloudFront invalidation 成功 | `gh run view --log` | invalidation ID が出力 | | |

## 8. API 認証確認

| # | 確認項目 | 操作 | 期待結果 | 結果 | 備考 |
|---|---------|------|---------|------|------|
| 21 | 未認証で API アクセス | `curl -s https://<cf_domain>/tasks` | 401 Unauthorized | | |
| 22 | `/` は認証不要 | `curl -s https://<cf_domain>/` | 200 `{"message": "Hello, World!"}` | | |
| 23 | `/health` は認証不要 | `curl -s https://<cf_domain>/health` | 200 `{"status": "healthy"}` | | |

## 9. Web UI 認証フロー確認

| # | 確認項目 | 操作 | 期待結果 | 結果 | 備考 |
|---|---------|------|---------|------|------|
| 24 | ログイン画面表示 | ブラウザで CloudFront URL を開く | ログイン画面が表示される | | |
| 25 | サインアップ画面遷移 | 「Sign up」リンクをクリック | サインアップ画面が表示される | | |
| 26 | サインアップ実行 | email + password 入力 → 「Sign Up」 | 確認コード画面に遷移 | | |
| 27 | メール確認コード受信 | メールボックスを確認 | 確認コードが届いている | | |
| 28 | アカウント確認 | 確認コード入力 → 「Confirm」 | ログイン画面にリダイレクト | | |
| 29 | ログイン実行 | email + password 入力 → 「Log In」 | タスク一覧画面が表示される | | |
| 30 | タスク作成 | 「New Task」→ タイトル入力 → 「Create Task」 | タスクが作成される | | |
| 31 | タスク完了切替 | 「Mark Complete」 | ステータスが Completed になる | | |
| 32 | ログアウト | 「Logout」ボタン | ログイン画面にリダイレクト | | |
| 33 | 未認証リダイレクト | ログアウト後に `/` にアクセス | ログイン画面にリダイレクト | | |

## 10. 確認結果サマリ

| カテゴリ | 確認件数 | PASS | FAIL | 備考 |
|---------|---------|------|------|------|
| CI/CD パイプライン | 6 | | | |
| Terraform apply | 6 | | | |
| Cognito User Pool | 2 | | | |
| WAF | 2 | | | |
| CD パイプライン | 4 | | | |
| API 認証 | 3 | | | |
| Web UI 認証フロー | 10 | | | |
| **合計** | **33** | | | |
