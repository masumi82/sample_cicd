# 動作確認記録 (v2)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-03 |
| バージョン | 2.0 |
| 前バージョン | [verification.md](verification.md) (v1.0) |

## 1. 確認概要

本ドキュメントは `deploy_procedure_v2.md` に従ってデプロイを実施した後の動作確認記録である。
各項目を実施し、結果を記録する。

## 2. 環境情報

| 項目 | 値 |
|------|------|
| AWS アカウント ID | （`aws sts get-caller-identity` の値を記入） |
| AWS リージョン | ap-northeast-1 |
| ALB DNS 名 | （`terraform output alb_dns_name` の値を記入） |
| ECR リポジトリ URL | （`terraform output ecr_repository_url` の値を記入） |
| RDS エンドポイント | （`terraform output rds_endpoint` の値を記入） |
| Secrets Manager ARN | （`terraform output secrets_manager_arn` の値を記入） |
| GitHub リポジトリ URL | （リポジトリ URL を記入） |
| 実施日 | （実施日を記入） |
| 実施者 | （実施者を記入） |

## 3. インフラ構築確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 1 | Terraform init 成功 | `terraform init` | "successfully initialized"（random provider 含む） | | |
| 2 | Terraform plan 確認 | `terraform plan` | v2 新規 13 リソース追加 + 変更 1 | | |
| 3 | Terraform apply 成功 | `terraform apply` | "Apply complete!" | | |
| 4 | ALB DNS 名の取得 | `terraform output alb_dns_name` | DNS 名が表示される | | |
| 5 | ECR URL の取得 | `terraform output ecr_repository_url` | ECR URL が表示される | | |
| 6 | RDS エンドポイントの取得 | `terraform output rds_endpoint` | エンドポイントが表示される | | |
| 7 | Secrets Manager ARN の取得 | `terraform output secrets_manager_arn` | ARN が表示される | | |

## 4. RDS 確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 8 | RDS ステータス | `aws rds describe-db-instances --db-instance-identifier sample-cicd --query 'DBInstances[0].DBInstanceStatus'` | "available" | | |
| 9 | RDS エンジン | `aws rds describe-db-instances --db-instance-identifier sample-cicd --query 'DBInstances[0].Engine'` | "postgres" | | |
| 10 | Secrets Manager 存在 | `aws secretsmanager describe-secret --secret-id sample-cicd/db-credentials` | シークレットが存在する | | |

## 5. 初回デプロイ確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 11 | ECR ログイン | `aws ecr get-login-password ... \| docker login ...` | "Login Succeeded" | | |
| 12 | Docker ビルド | `docker build -t ... -f app/Dockerfile .` | ビルド成功 | | |
| 13 | ECR プッシュ | `docker push ...` | プッシュ成功 | | |
| 14 | ECS サービス更新 | `aws ecs update-service --force-new-deployment ...` | サービス更新開始 | | |
| 15 | サービス安定化 | `aws ecs wait services-stable ...` | タイムアウトなく完了 | | |

## 6. アプリケーション動作確認（v1 エンドポイント）

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 16 | GET / | `curl http://<ALB_DNS>/` | `{"message":"Hello, World!"}` (200) | | |
| 17 | GET /health | `curl http://<ALB_DNS>/health` | `{"status":"healthy"}` (200) | | |

## 7. アプリケーション動作確認（v2 タスク CRUD）

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 18 | GET /tasks（空） | `curl http://<ALB_DNS>/tasks` | `[]` (200) | | |
| 19 | POST /tasks | `curl -X POST ... -d '{"title":"Test","description":"v2 test"}'` | 201, タスクオブジェクト返却 | | |
| 20 | GET /tasks/{id} | `curl http://<ALB_DNS>/tasks/1` | 200, 作成したタスク | | |
| 21 | PUT /tasks/{id} | `curl -X PUT ... -d '{"completed":true}'` | 200, completed=true | | |
| 22 | GET /tasks（1件） | `curl http://<ALB_DNS>/tasks` | 1 件のタスク配列 | | |
| 23 | DELETE /tasks/{id} | `curl -X DELETE http://<ALB_DNS>/tasks/1` | 204, ボディなし | | |
| 24 | GET /tasks/{id}（削除後） | `curl http://<ALB_DNS>/tasks/1` | 404, `{"detail":"Task not found"}` | | |
| 25 | GET /tasks（削除後） | `curl http://<ALB_DNS>/tasks` | `[]` (200) | | |

## 8. データ永続化確認

| # | 確認項目 | 確認方法 | 期待結果 | 結果 | 備考 |
|---|---------|---------|---------|------|------|
| 26 | タスク作成後にECS再デプロイ | タスク作成 → `aws ecs update-service --force-new-deployment` → サービス安定化後に GET /tasks | 作成済みタスクが保持されている | | |

## 9. CI/CD パイプライン確認

| # | 確認項目 | 確認方法 | 期待結果 | 結果 | 備考 |
|---|---------|---------|---------|------|------|
| 27 | CI — Lint | GitHub Actions ログ | `ruff check` エラー 0 件 | | |
| 28 | CI — Test | GitHub Actions ログ | 18 tests passed | | |
| 29 | CI — Build | GitHub Actions ログ | `docker build -f app/Dockerfile .` 成功 | | |
| 30 | CD — ECR Push | GitHub Actions ログ | イメージ push 成功 | | |
| 31 | CD — ECS Deploy | GitHub Actions ログ | デプロイ完了（service stable） | | |

## 10. ログ確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 32 | CloudWatch ロググループ | `aws logs describe-log-groups --log-group-name-prefix /ecs/sample-cicd` | ロググループが存在する | | |
| 33 | Alembic マイグレーションログ | CloudWatch Logs を確認 | `Running upgrade -> 001` が表示される | | |
| 34 | uvicorn 起動ログ | CloudWatch Logs を確認 | `Uvicorn running on ...` が表示される | | |

## 11. 確認結果サマリ

| カテゴリ | 合計 | PASS | FAIL | 合格率 |
|---------|------|------|------|--------|
| インフラ構築 (#1-7) | 7 | | | |
| RDS 確認 (#8-10) | 3 | | | |
| 初回デプロイ (#11-15) | 5 | | | |
| v1 動作確認 (#16-17) | 2 | | | |
| v2 CRUD 確認 (#18-25) | 8 | | | |
| データ永続化 (#26) | 1 | | | |
| CI/CD (#27-31) | 5 | | | |
| ログ (#32-34) | 3 | | | |
| **合計** | **34** | | | |

## 12. 判定

- ☐ **合格** — 全 34 項目が PASS
- ☐ **条件付き合格** — FAIL 項目があるが運用に支障なし（備考に理由を記載）
- ☐ **不合格** — 重大な FAIL 項目あり（是正処置が必要）

### 判定者コメント

（コメントを記入）

### 検出された問題と対応

| # | 問題 | 原因 | 対応 |
|---|------|------|------|
| | | | |

## 13. クリーンアップ記録

| # | 作業項目 | 実施日 | 結果 | 備考 |
|---|---------|--------|------|------|
| 1 | ECR イメージ削除 | | ☐ 完了 | |
| 2 | `terraform destroy` 実行 | | ☐ 完了 | RDS 削除に数分かかる |
| 3 | IAM ユーザー削除 | | ☐ 完了 / ☐ スキップ | |
| 4 | GitHub Secrets 削除 | | ☐ 完了 / ☐ スキップ | |
| 5 | ローカル state 削除 | | ☐ 完了 / ☐ 未実施 | |
