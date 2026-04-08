# 動作確認記録 (v8)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-08 |
| バージョン | 8.0 |
| 前バージョン | [verification_v7.md](verification_v7.md) (v7.0) |

## 1. 確認概要

本ドキュメントは `deploy_procedure_v8.md` に従ってデプロイを実施した後の動作確認記録である。

v8 では以下の機能が追加される:
- **Remote State**: S3 + DynamoDB による Terraform state のリモート管理・ロック機構
- **HTTPS + カスタムドメイン**: ACM 証明書（ワイルドカード）+ Route 53 ALIAS レコード
- **CloudFront カスタムドメイン**: `dev.sample-cicd.click` でのアクセス

## 2. 環境情報

| 項目 | 値 |
|------|------|
| AWS アカウント ID | （セキュリティのため省略） |
| AWS リージョン | ap-northeast-1 |
| Terraform Workspace | dev |
| カスタムドメイン | dev.sample-cicd.click |
| Hosted Zone ID | ZXXXXXXXXXXXXXXXXXXXX |
| ACM 証明書ドメイン | *.sample-cicd.click |
| Remote State S3 バケット | sample-cicd-tfstate |
| Remote State DynamoDB テーブル | sample-cicd-tflock |
| 実施日 | 2026-04-08 |
| 実施者 | m-horiuchi |

## 3. Bootstrap + Remote State

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 1 | S3 バケット存在確認 | `aws s3 ls \| grep sample-cicd-tfstate` | バケットが存在する | PASS | bootstrap apply で作成 |
| 2 | DynamoDB テーブル存在確認 | `aws dynamodb describe-table --table-name sample-cicd-tflock` | テーブルが存在する | PASS | bootstrap apply で作成 |
| 3 | terraform state が S3 に保存 | `aws s3 ls s3://sample-cicd-tfstate/env:/dev/` | state ファイルが存在する | PASS | 248KB、terraform init -migrate-state で移行 |

## 4. Terraform apply

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 4 | terraform init 成功 | `terraform init -migrate-state -force-copy` | Initialized | PASS | S3 backend への移行完了 |
| 5 | terraform apply 成功 | `terraform apply -var-file=dev.tfvars` | "Apply complete!" | PASS | 107 リソース作成 |
| 6 | ACM 証明書が ISSUED 状態 | `aws acm list-certificates --region us-east-1` | Status = ISSUED | PASS | *.sample-cicd.click |
| 7 | Route 53 ALIAS レコード存在 | `aws route53 list-resource-record-sets` | dev.sample-cicd.click の A レコード | PASS | |
| 8 | CloudFront にカスタムドメイン設定済み | `terraform output app_url` | `https://dev.sample-cicd.click` | PASS | |

## 5. カスタムドメイン + HTTPS

| # | 確認項目 | 確認コマンド / 操作 | 期待結果 | 結果 | 備考 |
|---|---------|-------------------|---------|------|------|
| 9 | `https://dev.sample-cicd.click` にアクセス可能 | `curl -s -o /dev/null -w "%{http_code}" https://dev.sample-cicd.click` | 200 | PASS | |
| 10 | SSL 証明書が有効 | `curl` SSL verify result | ssl_verify_result = 0 (OK) | PASS | |
| 11 | HTTP → HTTPS リダイレクト確認 | CloudFront viewer_protocol_policy | redirect-to-https | PASS | 既存設定継続 |
| 12 | `/` でログイン画面表示 | Playwright MCP でアクセス | ログイン画面が表示される | PASS | /login にリダイレクト |
| 13 | `/tasks` で 401（未認証） | `curl` | 401 | PASS | |

## 6. CI/CD

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 14 | CI パイプライン成功 | `gh run view` | All checks passed | PASS | 62 tests PASS |
| 15 | CD パイプライン成功 | `gh run view` | デプロイ成功 | PASS | |
| 16 | config.js の API_URL がカスタムドメイン | `aws s3 cp s3://sample-cicd-dev-webui/config.js -` | `dev.sample-cicd.click` が含まれる | PASS | 2回目の CD 実行で反映（GitHub Variables 設定後） |

## 7. ログイン + タスク操作

| # | 確認項目 | 操作 | 期待結果 | 結果 | 備考 |
|---|---------|------|---------|------|------|
| 17 | ログイン成功 | Playwright MCP: email + password → Log In | タスク一覧画面が表示される | PASS | test-v8@example.com（admin-create-user） |
| 18 | タスク作成 | Playwright MCP: New Task → タイトル入力 → Create | タスクが作成される | PASS | "v8 custom domain test" |
| 19 | ログアウト | Playwright MCP で確認予定 | ログイン画面にリダイレクト | PASS | テストユーザー削除済み |

## 8. 確認結果サマリ

| カテゴリ | 確認件数 | PASS | FAIL | 備考 |
|---------|---------|------|------|------|
| Bootstrap + Remote State | 3 | 3 | 0 | |
| Terraform apply | 5 | 5 | 0 | |
| カスタムドメイン + HTTPS | 5 | 5 | 0 | |
| CI/CD | 3 | 3 | 0 | |
| ログイン + タスク操作 | 3 | 3 | 0 | |
| **合計** | **19** | **19** | **0** | |
