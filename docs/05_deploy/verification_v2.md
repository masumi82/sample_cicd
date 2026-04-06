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
| AWS アカウント ID | （v1 と同一） |
| AWS リージョン | ap-northeast-1 |
| ALB DNS 名 | （terraform output で取得済み） |
| ECR リポジトリ URL | （terraform output で取得済み） |
| RDS エンドポイント | （terraform output で取得済み） |
| Secrets Manager ARN | （terraform output で取得済み） |
| GitHub リポジトリ URL | https://github.com/masumi82/sample_cicd |
| 実施日 | 2026-04-03 |
| 実施者 | m-horiuchi |

## 3. インフラ構築確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 1 | Terraform init 成功 | `terraform init` | "successfully initialized"（random provider 含む） | PASS | |
| 2 | Terraform plan 確認 | `terraform plan` | v2 新規 13 リソース追加 + 変更 1 | PASS | |
| 3 | Terraform apply 成功 | `terraform apply` | "Apply complete!" | PASS | RDS 作成に約 10 分 |
| 4 | ALB DNS 名の取得 | `terraform output alb_dns_name` | DNS 名が表示される | PASS | |
| 5 | ECR URL の取得 | `terraform output ecr_repository_url` | ECR URL が表示される | PASS | |
| 6 | RDS エンドポイントの取得 | `terraform output rds_endpoint` | エンドポイントが表示される | PASS | |
| 7 | Secrets Manager ARN の取得 | `terraform output secrets_manager_arn` | ARN が表示される | PASS | |

## 4. RDS 確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 8 | RDS ステータス | `aws rds describe-db-instances --db-instance-identifier sample-cicd --query 'DBInstances[0].DBInstanceStatus'` | "available" | PASS | |
| 9 | RDS エンジン | `aws rds describe-db-instances --db-instance-identifier sample-cicd --query 'DBInstances[0].Engine'` | "postgres" | PASS | |
| 10 | Secrets Manager 存在 | `aws secretsmanager describe-secret --secret-id sample-cicd/db-credentials` | シークレットが存在する | PASS | |

## 5. 初回デプロイ確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 11 | ECR ログイン | `aws ecr get-login-password ... \| docker login ...` | "Login Succeeded" | PASS | |
| 12 | Docker ビルド | `docker build -t ... -f app/Dockerfile .` | ビルド成功 | PASS | |
| 13 | ECR プッシュ | `docker push ...` | プッシュ成功 | PASS | |
| 14 | ECS サービス更新 | `aws ecs update-service --force-new-deployment ...` | サービス更新開始 | PASS | |
| 15 | サービス安定化 | `aws ecs wait services-stable ...` | タイムアウトなく完了 | PASS | |

## 6. アプリケーション動作確認（v1 エンドポイント）

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 16 | GET / | `curl http://<ALB_DNS>/` | `{"message":"Hello, World!"}` (200) | PASS | |
| 17 | GET /health | `curl http://<ALB_DNS>/health` | `{"status":"healthy"}` (200) | PASS | |

## 7. アプリケーション動作確認（v2 タスク CRUD）

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 18 | GET /tasks（空） | `curl http://<ALB_DNS>/tasks` | `[]` (200) | PASS | |
| 19 | POST /tasks | `curl -X POST ... -d '{"title":"First task","description":"Testing v2 deployment"}'` | 201, タスクオブジェクト返却 | PASS | |
| 20 | GET /tasks/{id} | `curl http://<ALB_DNS>/tasks/{id}` | 200, 作成したタスク | PASS | |
| 21 | PUT /tasks/{id} | `curl -X PUT ... -d '{"completed":true}'` | 200, completed=true | PASS | |
| 22 | GET /tasks（1件） | `curl http://<ALB_DNS>/tasks` | 1 件のタスク配列 | PASS | |
| 23 | DELETE /tasks/{id} | `curl -X DELETE http://<ALB_DNS>/tasks/{id}` | 204, ボディなし | PASS | |
| 24 | GET /tasks/{id}（削除後） | `curl http://<ALB_DNS>/tasks/{id}` | 404, `{"detail":"Task not found"}` | PASS | |
| 25 | GET /tasks（削除後） | `curl http://<ALB_DNS>/tasks` | `[]` (200) | PASS | |

## 8. データ永続化確認

| # | 確認項目 | 確認方法 | 期待結果 | 結果 | 備考 |
|---|---------|---------|---------|------|------|
| 26 | タスク作成後にECS再デプロイ | タスク作成 → CI/CD 再デプロイ → GET /tasks | 作成済みタスクが保持されている | PASS | 再デプロイ後もシーケンス（auto-increment）が維持されていることで確認。id:1 削除後の新規作成で id:2 が付番された |

## 9. CI/CD パイプライン確認

| # | 確認項目 | 確認方法 | 期待結果 | 結果 | 備考 |
|---|---------|---------|---------|------|------|
| 27 | CI — Lint | GitHub Actions ログ | `ruff check` エラー 0 件 | PASS | |
| 28 | CI — Test | GitHub Actions ログ | 18 tests passed | PASS | 初回は `DATABASE_URL` 未設定で失敗。CI に `DATABASE_URL: sqlite://` を追加して解消 |
| 29 | CI — Build | GitHub Actions ログ | `docker build -f app/Dockerfile .` 成功 | PASS | |
| 30 | CD — ECR Push | GitHub Actions ログ | イメージ push 成功 | PASS | |
| 31 | CD — ECS Deploy | GitHub Actions ログ | デプロイ完了（service stable） | PASS | |

## 10. ログ確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 32 | CloudWatch ロググループ | `aws logs describe-log-groups --log-group-name-prefix /ecs/sample-cicd` | ロググループが存在する | PASS | |
| 33 | Alembic マイグレーションログ | CloudWatch Logs を確認 | `Running upgrade -> 001` が表示される | PASS | |
| 34 | uvicorn 起動ログ | CloudWatch Logs を確認 | `Uvicorn running on ...` が表示される | PASS | アクセスログに全 CRUD 操作のログが記録されていることも確認 |

## 11. 確認結果サマリ

| カテゴリ | 合計 | PASS | FAIL | 合格率 |
|---------|------|------|------|--------|
| インフラ構築 (#1-7) | 7 | 7 | 0 | 100% |
| RDS 確認 (#8-10) | 3 | 3 | 0 | 100% |
| 初回デプロイ (#11-15) | 5 | 5 | 0 | 100% |
| v1 動作確認 (#16-17) | 2 | 2 | 0 | 100% |
| v2 CRUD 確認 (#18-25) | 8 | 8 | 0 | 100% |
| データ永続化 (#26) | 1 | 1 | 0 | 100% |
| CI/CD (#27-31) | 5 | 5 | 0 | 100% |
| ログ (#32-34) | 3 | 3 | 0 | 100% |
| **合計** | **34** | **34** | **0** | **100%** |

## 12. 判定

- ☑ **合格** — 全 34 項目が PASS
- ☐ **条件付き合格** — FAIL 項目があるが運用に支障なし（備考に理由を記載）
- ☐ **不合格** — 重大な FAIL 項目あり（是正処置が必要）

### 判定者コメント

全 34 項目 PASS。デプロイ過程で 2 件の問題が発生したが、いずれも修正済み。修正後は全機能が正常に動作することを確認した。

### 検出された問題と対応

| # | 問題 | 原因 | 対応 |
|---|------|------|------|
| 1 | `GET /tasks` および `POST /tasks` がレスポンスボディを返さない | FastAPI ルーターで `@router.get("/")` と定義すると `/tasks/`（末尾スラッシュ付き）で登録され、`/tasks` へのリクエストが 307 リダイレクトとなる。curl はデフォルトでリダイレクトを追従しない | ルーターのパスを `"/"` から `""` に変更 (`@router.get("")`, `@router.post("")`) |
| 2 | CI テストジョブで `KeyError: 'DB_USERNAME'` エラー | `database.py` がモジュールインポート時に `_build_database_url()` を実行するが、CI 環境では `DATABASE_URL` も `DB_*` 環境変数も未設定 | CI ワークフローの Test ステップに `DATABASE_URL: sqlite://` 環境変数を追加 |

## 13. クリーンアップ記録

| # | 作業項目 | 実施日 | 結果 | 備考 |
|---|---------|--------|------|------|
| 1 | ECR イメージ削除 | 2026-04-03 | ☑ 完了 | |
| 2 | `terraform destroy` 実行 | 2026-04-03 | ☑ 完了 | v2 リソース含む全リソース削除 |
| 3 | IAM ユーザー削除 | — | ☐ スキップ | v1 から継続利用 |
| 4 | GitHub Secrets 削除 | — | ☐ スキップ | IAM ユーザー保持のため維持 |
| 5 | ローカル state 削除 | — | ☐ 未実施 | 再デプロイ時に備えて保持可 |
