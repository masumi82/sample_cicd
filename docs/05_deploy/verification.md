# 動作確認記録

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-02 |
| バージョン | 1.0 |

## 1. 確認概要

本ドキュメントは `deploy_procedure.md` に従ってデプロイを実施した後の動作確認記録である。
各項目を実施し、結果を記録する。

## 2. 環境情報

| 項目 | 値 |
|------|------|
| AWS アカウント ID | （記入） |
| AWS リージョン | ap-northeast-1 |
| ALB DNS 名 | （`terraform output alb_dns_name` の値を記入） |
| ECR リポジトリ URL | （`terraform output ecr_repository_url` の値を記入） |
| GitHub リポジトリ URL | （記入） |
| 実施日 | （記入） |
| 実施者 | （記入） |

## 3. インフラ構築確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 1 | Terraform init 成功 | `terraform init` | "successfully initialized" | ☐ PASS / ☐ FAIL | |
| 2 | Terraform plan 確認 | `terraform plan` | 21 リソース追加 | ☐ PASS / ☐ FAIL | |
| 3 | Terraform apply 成功 | `terraform apply` | "Apply complete! Resources: 21 added" | ☐ PASS / ☐ FAIL | |
| 4 | ALB DNS 名の取得 | `terraform output alb_dns_name` | DNS 名が表示される | ☐ PASS / ☐ FAIL | |
| 5 | ECR URL の取得 | `terraform output ecr_repository_url` | ECR URL が表示される | ☐ PASS / ☐ FAIL | |

## 4. 初回デプロイ確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 6 | ECR ログイン | `aws ecr get-login-password ...` | "Login Succeeded" | ☐ PASS / ☐ FAIL | |
| 7 | Docker ビルド | `docker build -t ... ./app` | ビルド成功 | ☐ PASS / ☐ FAIL | |
| 8 | ECR プッシュ | `docker push ...` | プッシュ成功 | ☐ PASS / ☐ FAIL | |
| 9 | ECS サービス更新 | `aws ecs update-service --force-new-deployment ...` | サービス更新開始 | ☐ PASS / ☐ FAIL | |
| 10 | サービス安定化 | `aws ecs wait services-stable ...` | タイムアウトなく完了 | ☐ PASS / ☐ FAIL | |

## 5. アプリケーション動作確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 11 | GET / | `curl http://<ALB_DNS>/` | `{"message":"Hello, World!"}` (200 OK) | ☐ PASS / ☐ FAIL | |
| 12 | GET /health | `curl http://<ALB_DNS>/health` | `{"status":"healthy"}` (200 OK) | ☐ PASS / ☐ FAIL | |
| 13 | GET /notfound | `curl -s -o /dev/null -w "%{http_code}" http://<ALB_DNS>/notfound` | `404` | ☐ PASS / ☐ FAIL | |
| 14 | POST / | `curl -s -o /dev/null -w "%{http_code}" -X POST http://<ALB_DNS>/` | `405` | ☐ PASS / ☐ FAIL | |

## 6. CI/CD パイプライン確認

| # | 確認項目 | 確認方法 | 期待結果 | 結果 | 備考 |
|---|---------|---------|---------|------|------|
| 15 | GitHub Secrets 設定 | GitHub Settings → Secrets | AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY が設定済み | ☐ PASS / ☐ FAIL | |
| 16 | CI ジョブ — Lint | GitHub Actions ログ | `ruff check` エラー 0 件 | ☐ PASS / ☐ FAIL | |
| 17 | CI ジョブ — Test | GitHub Actions ログ | 6 tests passed | ☐ PASS / ☐ FAIL | |
| 18 | CI ジョブ — Build | GitHub Actions ログ | Docker build 成功 | ☐ PASS / ☐ FAIL | |
| 19 | CD ジョブ — ECR Push | GitHub Actions ログ | イメージ push 成功 | ☐ PASS / ☐ FAIL | |
| 20 | CD ジョブ — ECS Deploy | GitHub Actions ログ | デプロイ完了（service stable） | ☐ PASS / ☐ FAIL | |

## 7. ログ確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 21 | CloudWatch ロググループ | `aws logs describe-log-groups --log-group-name-prefix /ecs/sample-cicd` | ロググループが存在する | ☐ PASS / ☐ FAIL | |
| 22 | コンテナログ | `aws logs get-log-events ...` | uvicorn 起動ログが出力されている | ☐ PASS / ☐ FAIL | |

## 8. 確認結果サマリ

| カテゴリ | 合計 | PASS | FAIL | 合格率 |
|---------|------|------|------|--------|
| インフラ構築 (#1-5) | 5 | | | |
| 初回デプロイ (#6-10) | 5 | | | |
| アプリ動作 (#11-14) | 4 | | | |
| CI/CD (#15-20) | 6 | | | |
| ログ (#21-22) | 2 | | | |
| **合計** | **22** | | | |

## 9. 判定

- ☐ **合格** — 全 22 項目が PASS
- ☐ **条件付き合格** — FAIL 項目があるが運用に支障なし（備考に理由を記載）
- ☐ **不合格** — 重大な FAIL 項目あり（是正処置が必要）

### 判定者コメント

（記入）

## 10. クリーンアップ記録

| # | 作業項目 | 実施日 | 結果 | 備考 |
|---|---------|--------|------|------|
| 1 | ECR イメージ削除 | | ☐ 完了 | |
| 2 | `terraform destroy` 実行 | | ☐ 完了 | |
| 3 | IAM ユーザー削除 | | ☐ 完了 | |
| 4 | GitHub Secrets 削除 | | ☐ 完了 | |
| 5 | ローカル state 削除 | | ☐ 完了 | |
