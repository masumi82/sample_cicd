# 動作確認記録 (v8)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-07 |
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
| 実施日 | |
| 実施者 | m-horiuchi |

## 3. Bootstrap + Remote State

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 1 | S3 バケット存在確認 | `aws s3 ls \| grep sample-cicd-tfstate` | バケットが存在する | | |
| 2 | DynamoDB テーブル存在確認 | `aws dynamodb describe-table --table-name sample-cicd-tflock` | テーブルが存在する | | |
| 3 | terraform state が S3 に保存 | `aws s3 ls s3://sample-cicd-tfstate/env:/dev/ --recursive` | state ファイルが存在する | | |

## 4. Terraform apply

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 4 | terraform init 成功 | `terraform init` | Initialized | | |
| 5 | terraform apply 成功 | `terraform apply -var-file=dev.tfvars` | "Apply complete!" | | |
| 6 | ACM 証明書が ISSUED 状態 | `aws acm list-certificates --region us-east-1` | Status = ISSUED | | |
| 7 | Route 53 ALIAS レコード存在 | `aws route53 list-resource-record-sets --hosted-zone-id <zone_id>` | dev.sample-cicd.click の A レコード（ALIAS） | | |
| 8 | CloudFront にカスタムドメイン設定済み | `terraform output app_url` | `https://dev.sample-cicd.click` | | |

## 5. カスタムドメイン + HTTPS

| # | 確認項目 | 確認コマンド / 操作 | 期待結果 | 結果 | 備考 |
|---|---------|-------------------|---------|------|------|
| 9 | `https://dev.sample-cicd.click` にアクセス可能 | `curl -s -o /dev/null -w "%{http_code}" https://dev.sample-cicd.click` | 200 | | |
| 10 | SSL 証明書が有効 | `curl -vI https://dev.sample-cicd.click 2>&1 \| grep subject` | *.sample-cicd.click が含まれる | | |
| 11 | HTTP → HTTPS リダイレクト確認 | CloudFront の viewer_protocol_policy 設定確認 | redirect-to-https | | |
| 12 | `/` でログイン画面表示 | ブラウザで `https://dev.sample-cicd.click` にアクセス | ログイン画面が表示される | | |
| 13 | `/tasks` で 401（未認証） | `curl -s -o /dev/null -w "%{http_code}" https://dev.sample-cicd.click/tasks` | 401 | | |

## 6. CI/CD

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 14 | CI パイプライン成功 | `gh run view --log` | All checks passed | | |
| 15 | CD パイプライン成功 | `gh run view --log` | デプロイ成功 | | |
| 16 | config.js の API_URL がカスタムドメイン | `aws s3 cp s3://sample-cicd-dev-webui/config.js -` | `dev.sample-cicd.click` が含まれる | | |

## 7. ログイン + タスク操作

| # | 確認項目 | 操作 | 期待結果 | 結果 | 備考 |
|---|---------|------|---------|------|------|
| 17 | ログイン成功 | email + password 入力 → ログイン | タスク一覧画面が表示される | | |
| 18 | タスク作成 | 「New Task」→ タイトル入力 → 作成 | タスクが作成される | | |
| 19 | ログアウト | 「Logout」ボタンをクリック | ログイン画面にリダイレクト | | |

## 8. 確認結果サマリ

| カテゴリ | 確認件数 | PASS | FAIL | 備考 |
|---------|---------|------|------|------|
| Bootstrap + Remote State | 3 | | | |
| Terraform apply | 5 | | | |
| カスタムドメイン + HTTPS | 5 | | | |
| CI/CD | 3 | | | |
| ログイン + タスク操作 | 3 | | | |
| **合計** | **19** | | | |
