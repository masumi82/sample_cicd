---
name: phase-gate
description: "Waterfall phase completion gate check. Use when completing a development phase to verify all deliverables are present and the phase is ready to close. Invoke with the phase number as argument, e.g. /phase-gate 1"
user-invocable: true
---

# Phase Gate Check

Perform a phase completion review for Phase `$ARGUMENTS` of the sample_cicd project.

All output must be in Japanese.

## Phase Definitions

> **Note**: v1〜v6 の成果物を管理する。v1・v2・v3・v4・v5 は完了済み。
> 引数が `1`〜`5` の場合は v6 のフェーズをチェックする。

### Phase 1: Requirements (要件定義)
Required deliverables (v1 & v2 — 完了済み):
- [x] `docs/01_requirements/requirements.md` — v1 機能要件・非機能要件
- [x] `docs/01_requirements/requirements_v2.md` — v2 タスク管理 API + RDS の要件
- [x] CLAUDE.md に v1・v2 の情報が反映済み

Required deliverables (v3 — 完了済み):
- [x] `docs/01_requirements/requirements_v3.md` — Auto Scaling + HTTPS準備の機能要件・非機能要件
- [x] CLAUDE.md に v3 の情報が反映済みであること

Required deliverables (v4 — 完了済み):
- [x] `docs/01_requirements/requirements_v4.md` — SQS + Lambda + EventBridge イベント駆動アーキテクチャの要件
- [x] CLAUDE.md に v4 の情報が反映済みであること

Required deliverables (v5 — 完了済み):
- [x] `docs/01_requirements/requirements_v5.md` — S3 + CloudFront + Presigned URL + Terraform Workspace の要件
- [x] CLAUDE.md に v5 の情報が反映済みであること

Required deliverables (v6):
- [ ] `docs/01_requirements/requirements_v6.md` — Observability (CloudWatch Dashboard/Alarms, X-Ray, SNS, 構造化ログ) + Web UI (React SPA on S3+CloudFront, CORS, フロントエンド CI/CD) の要件
- [ ] CLAUDE.md に v6 の情報が反映済みであること

### Phase 2: Design (設計)
Required deliverables (v1 & v2 — 完了済み):
- [x] `docs/02_design/architecture.md` — v1 アーキテクチャ設計
- [x] `docs/02_design/api.md` — v1 API設計
- [x] `docs/02_design/cicd.md` — v1 CI/CDパイプライン設計
- [x] `docs/02_design/infrastructure.md` — v1 Terraform リソース設計
- [x] `docs/02_design/architecture_v2.md` — v2 アーキテクチャ設計
- [x] `docs/02_design/api_v2.md` — v2 API設計（タスク CRUD）
- [x] `docs/02_design/database.md` — DB設計
- [x] `docs/02_design/infrastructure_v2.md` — v2 Terraform リソース設計
- [x] `docs/02_design/cicd_v2.md` — v2 CI/CD パイプライン設計

Required deliverables (v3 — 完了済み):
- [x] `docs/02_design/architecture_v3.md` — アーキテクチャ設計（Auto Scaling + HTTPS準備）
- [x] `docs/02_design/infrastructure_v3.md` — Terraform リソース設計（Auto Scaling + RDS Multi-AZ + HTTPS コード）
- [x] `docs/02_design/cicd_v3.md` — CI/CD パイプライン設計（変更点。変更なしの場合はその旨を記載）

Required deliverables (v4 — 完了済み):
- [x] `docs/02_design/architecture_v4.md` — アーキテクチャ設計（SQS + Lambda + EventBridge）
- [x] `docs/02_design/infrastructure_v4.md` — Terraform リソース設計（SQS, Lambda, EventBridge, VPC エンドポイント）
- [x] `docs/02_design/cicd_v4.md` — CI/CD パイプライン設計（Lambda デプロイ追加）

Required deliverables (v5 — 完了済み):
- [x] `docs/02_design/architecture_v5.md` — アーキテクチャ設計（S3 + CloudFront + Terraform Workspace）
- [x] `docs/02_design/infrastructure_v5.md` — Terraform リソース設計（S3, CloudFront, OAC, Workspace 命名）
- [x] `docs/02_design/cicd_v5.md` — CI/CD パイプライン設計（DEPLOY_ENV + 環境名対応）

Required deliverables (v6):
- [ ] `docs/02_design/architecture_v6.md` — アーキテクチャ設計（Observability: Dashboard/Alarms/X-Ray/構造化ログ + Web UI: React SPA on S3+CloudFront）
- [ ] `docs/02_design/infrastructure_v6.md` — Terraform リソース設計（monitoring.tf, sns.tf, webui.tf, X-Ray sidecar, IAM 更新）
- [ ] `docs/02_design/cicd_v6.md` — CI/CD パイプライン設計（Node.js セットアップ + フロントエンドビルド・デプロイ）

### Phase 3: Implementation (実装)
Required deliverables (v1 & v2 — 完了済み):
- [x] `app/main.py`, `app/database.py`, `app/models.py`, `app/schemas.py` — FastAPI + SQLAlchemy
- [x] `app/routers/tasks.py` — タスク CRUD ルーター
- [x] `app/Dockerfile`, `app/requirements.txt`, `app/alembic.ini`, `app/alembic/` — コンテナ・マイグレーション
- [x] `infra/*.tf` — v2 Terraform（RDS, Secrets Manager, プライベートサブネット含む）
- [x] `.github/workflows/ci-cd.yml` — CI/CD ワークフロー

Required deliverables (v3 — 完了済み):
- [x] `infra/autoscaling.tf` — Application Auto Scaling（ECS タスク数自動調整）
- [x] `infra/rds.tf` — RDS Multi-AZ 対応（`multi_az = true` に変更）
- [x] `infra/https.tf` — ACM + Route53 + ALB HTTPS リスナー（コードのみ、`enabled` 変数で制御）
- [x] `infra/variables.tf` — Auto Scaling 設定変数追加（min/max タスク数, CPU 目標値）
- [x] アプリケーションコードの変更なし（Terraform のみ）
- [x] Code passes lint and Terraform validate

Required deliverables (v4 — 完了済み):
- [x] `app/services/events.py` — SQS / EventBridge 送信サービス（boto3）
- [x] `app/routers/tasks.py` — タスク作成・更新時のイベント発行コード追加
- [x] `app/requirements.txt` — boto3 追加
- [x] `lambda/task_created_handler.py` — SQS トリガー Lambda
- [x] `lambda/task_completed_handler.py` — EventBridge トリガー Lambda
- [x] `lambda/task_cleanup_handler.py` — Scheduler トリガー Lambda（VPC 内 RDS 接続）
- [x] `infra/sqs.tf` — SQS キュー + DLQ
- [x] `infra/lambda.tf` — Lambda 関数 3 つ
- [x] `infra/eventbridge.tf` — EventBridge カスタムバス + ルール + Scheduler
- [x] `infra/variables.tf` — v4 変数追加
- [x] Code passes lint and Terraform validate

Required deliverables (v5 — 完了済み):
- [x] `app/models.py` — Attachment モデル追加
- [x] `app/schemas.py` — Attachment スキーマ + filename サニタイズバリデータ追加
- [x] `app/services/storage.py` — S3 Presigned URL 生成 + オブジェクト削除サービス
- [x] `app/routers/attachments.py` — 添付ファイル CRUD エンドポイント（4 個）
- [x] `app/alembic/versions/002_create_attachments_table.py` — Alembic マイグレーション
- [x] `app/main.py` — attachments router 登録
- [x] `app/routers/tasks.py` — タスク削除時の S3 オブジェクト一括削除
- [x] `infra/main.tf` — locals ブロック + Workspace 命名（`${local.prefix}`）
- [x] `infra/s3.tf` — S3 バケット + パブリックアクセスブロック + バケットポリシー + CORS + 暗号化 + バージョニング
- [x] `infra/cloudfront.tf` — CloudFront ディストリビューション + OAC
- [x] `infra/variables.tf` — v5 変数追加（db_multi_az, cloudfront_price_class, cors_allowed_origins, s3_versioning_enabled）
- [x] `infra/ecs.tf` — S3_BUCKET_NAME, CLOUDFRONT_DOMAIN_NAME 環境変数追加
- [x] `infra/iam.tf` — ECS タスクロールに S3 PutObject/DeleteObject 権限追加
- [x] `infra/dev.tfvars`, `infra/prod.tfvars` — 環境別変数ファイル
- [x] 全 .tf ファイル — `${var.project_name}` → `${local.prefix}` 置換
- [x] `.github/workflows/ci-cd.yml` — DEPLOY_ENV + 環境名付きリソース名
- [x] Code passes lint and Terraform validate

Required deliverables (v6):
- [ ] `infra/monitoring.tf` — CloudWatch Dashboard (1) + Alarms (12)
- [ ] `infra/sns.tf` — SNS Topic（サブスクリプションは conditional: alarm_email が空なら作成しない）
- [ ] `infra/webui.tf` — Web UI 用 S3 バケット + CloudFront ディストリビューション（OAC, SPA フォールバック）
- [ ] `infra/variables.tf` — v6 変数追加（alarm 閾値, alarm_email 等）
- [ ] `infra/outputs.tf` — v6 出力追加（dashboard_url, sns_topic_arn, webui_bucket_name, webui_cloudfront_domain_name, webui_cloudfront_distribution_id）
- [ ] `infra/dev.tfvars` — v6 変数値追加
- [ ] `infra/prod.tfvars` — v6 変数値追加
- [ ] `infra/iam.tf` — ECS タスクロール + Lambda 3 ロールに X-Ray 権限追加
- [ ] `infra/ecs.tf` — X-Ray daemon サイドカー追加、環境変数追加（ENABLE_XRAY, CORS_ALLOWED_ORIGINS）、CPU/Memory 引き上げ
- [ ] `infra/logs.tf` — X-Ray daemon 用 CloudWatch Log Group 追加
- [ ] `infra/lambda.tf` — 3 関数に `tracing_config { mode = "Active" }` 追加
- [ ] `app/requirements.txt` — `aws-xray-sdk` 追加
- [ ] `app/main.py` — X-Ray SDK 初期化（graceful degradation）、CORSMiddleware 追加、構造化ログ（JSONFormatter）設定
- [ ] `lambda/task_created_handler.py` — 構造化ログ（JSONFormatter）追加
- [ ] `lambda/task_completed_handler.py` — 構造化ログ（JSONFormatter）追加
- [ ] `lambda/task_cleanup_handler.py` — 構造化ログ（JSONFormatter）追加
- [ ] `frontend/` — React + Vite SPA（package.json, vite.config.js, src/ 配下コンポーネント群）
- [ ] `.github/workflows/ci-cd.yml` — Node.js セットアップ + フロントエンドビルド (CI) + S3 sync + CloudFront invalidation (CD)
- [ ] Code passes lint (`ruff check app/ tests/ lambda/`) and Terraform validate
- [ ] Frontend builds successfully (`cd frontend && npm ci && npm run build`)

### Phase 4: Test (テスト)
Required deliverables (v1 & v2 — 完了済み):
- [x] `docs/04_test/test_plan.md` — v1 テスト計画書
- [x] `tests/test_main.py` — 6 テスト (TC-01〜TC-06)
- [x] `docs/04_test/test_plan_v2.md` — v2 テスト計画書
- [x] `tests/conftest.py`, `tests/test_tasks.py` — v2 CRUD テスト

Required deliverables (v3 — 完了済み):
- [x] `docs/04_test/test_plan_v3.md` — テスト計画書（v3）
- [x] v2 までの既存テストが引き続き全件 PASS
- [x] Auto Scaling 動作確認手順が test_plan_v3.md に記載済み

Required deliverables (v4 — 完了済み):
- [x] `docs/04_test/test_plan_v4.md` — テスト計画書（v4）
- [x] `tests/test_tasks.py` — SQS / EventBridge 送信のモックテスト追加（moto 使用）
- [x] v3 までの既存テストが引き続き全件 PASS

Required deliverables (v5 — 完了済み):
- [x] `docs/04_test/test_plan_v5.md` — テスト計画書（v5）
- [x] `tests/test_attachments.py` — 添付ファイル CRUD + スキーマバリデーションテスト（TC-24〜TC-39）
- [x] v4 までの既存テスト（TC-01〜TC-23）が引き続き全件 PASS

Required deliverables (v6):
- [ ] `docs/04_test/test_plan_v6.md` — テスト計画書（v6）
- [ ] `tests/test_observability.py` — CORS / 構造化ログ / X-Ray graceful degradation テスト（TC-40〜TC-46）
- [ ] v5 までの既存テスト（TC-01〜TC-39, 46 件）が引き続き全件 PASS

### Phase 5: Deploy (デプロイ)
Required deliverables (v1 & v2 — 完了済み):
- [x] `docs/05_deploy/deploy_procedure.md`, `docs/05_deploy/verification.md` — v1
- [x] `docs/05_deploy/deploy_procedure_v2.md`, `docs/05_deploy/verification_v2.md` — v2

Required deliverables (v3 — 完了済み):
- [x] `docs/05_deploy/deploy_procedure_v3.md` — デプロイ手順書（v3）
- [x] `docs/05_deploy/verification_v3.md` — 動作確認記録（v3）
- [x] `terraform apply` で Auto Scaling リソースが作成済み
- [x] RDS Multi-AZ が有効化済み
- [x] ECS タスク数が CPU 負荷に応じて増減することを確認

Required deliverables (v4 — 完了済み):
- [x] `docs/05_deploy/deploy_procedure_v4.md` — デプロイ手順書（v4）
- [x] `docs/05_deploy/verification_v4.md` — 動作確認記録（v4）
- [x] `terraform apply` で SQS / Lambda / EventBridge リソースが作成済み
- [x] `POST /tasks` 実行後に Lambda ログ（CloudWatch Logs）でイベント受信を確認
- [x] `PUT /tasks/{id}` で completed=true 更新後に Lambda ログで完了イベント受信を確認
- [x] Scheduler による定期クリーンアップ Lambda の実行を確認

Required deliverables (v5 — 完了済み):
- [x] `docs/05_deploy/deploy_procedure_v5.md` — デプロイ手順書（v5）
- [x] `docs/05_deploy/verification_v5.md` — 動作確認記録（v5）
- [x] v4 インフラ破棄 → Terraform Workspace `dev` 作成 → `terraform apply -var-file=dev.tfvars`
- [x] S3 バケット + CloudFront ディストリビューションが作成済み
- [x] `POST /tasks/{id}/attachments` で Presigned URL が返却されることを確認
- [x] Presigned URL 経由でファイルアップロード → CloudFront 経由でダウンロード可能を確認
- [x] `DELETE /tasks/{id}/attachments/{id}` で S3 オブジェクトが削除されることを確認
- [x] 全リソース名が `sample-cicd-dev-*` パターンであることを確認

Required deliverables (v6):
- [ ] `docs/05_deploy/deploy_procedure_v6.md` — デプロイ手順書（v6）
- [ ] `docs/05_deploy/verification_v6.md` — 動作確認記録（v6）
- [ ] `terraform apply` で CloudWatch Dashboard / Alarms / SNS Topic / Web UI S3 / Web UI CloudFront が作成済み
- [ ] CloudWatch Dashboard にメトリクス���表示されることを確認
- [ ] CloudWatch Alarms が作成され、大部分が OK 状態であることを確認
- [ ] X-Ray コンソールでトレースが表示されることを確認
- [ ] ECS ログが JSON 形式で出力されていることを確認（構造化ログ）
- [ ] Web UI (CloudFront URL) にブラウザからアクセスできることを確認
- [ ] Web UI からタスクの一覧・作成・編集・削除・完了切替が動作することを確認
- [ ] Web UI から添付ファイルのアップロード・ダウンロード・削除が動作すること���確認
- [ ] CI/CD パイプラインでフロントエンドビルド・デプロイが成功することを確認

## Review Process

1. Read the CLAUDE.md to understand the current project state
2. Check if ALL required deliverables for the specified phase exist
3. Read each deliverable and verify it has substantive content (not just placeholders)
4. For code deliverables (Phase 3+), verify the code is syntactically valid
5. **For Phase 3, 4: `code-review-expert` エージェントで変更コードのレビューを実施し、結果を出力に含める**
   - Phase 3: `app/` および `infra/` 配下の変更ファイル + `frontend/` 配下
   - Phase 4: `tests/` 配下のテストファイル
6. Output a checklist showing pass/fail for each item
7. If all items pass AND codex-review raises no blocking issues: declare the phase COMPLETE and recommend proceeding to the next phase
8. If any items fail or codex-review finds blocking issues: list what remains and do NOT approve phase completion

## Output Format

```
## Phase X Gate Review

| # | Deliverable | Status | Notes |
|---|------------|--------|-------|
| 1 | file/path  | PASS/FAIL | ... |

### Code Review (Phase 3・4 のみ)
(code-review-expert の結果サマリ。ブロッキング指摘があれば FAIL とする)

### Result: PASS / FAIL
(Summary and recommendation)
```
