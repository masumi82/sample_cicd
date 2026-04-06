---
name: phase-gate
description: "Waterfall phase completion gate check. Use when completing a development phase to verify all deliverables are present and the phase is ready to close. Invoke with the phase number as argument, e.g. /phase-gate 1"
user-invocable: true
---

# Phase Gate Check

Perform a phase completion review for Phase `$ARGUMENTS` of the sample_cicd project.

All output must be in Japanese.

## Phase Definitions

> **Note**: v1〜v4 の成果物を管理する。v1・v2・v3 は完了済み。
> 引数が `1`〜`5` の場合は v4 のフェーズをチェックする。

### Phase 1: Requirements (要件定義)
Required deliverables (v1 & v2 — 完了済み):
- [x] `docs/01_requirements/requirements.md` — v1 機能要件・非機能要件
- [x] `docs/01_requirements/requirements_v2.md` — v2 タスク管理 API + RDS の要件
- [x] CLAUDE.md に v1・v2 の情報が反映済み

Required deliverables (v3 — 完了済み):
- [x] `docs/01_requirements/requirements_v3.md` — Auto Scaling + HTTPS準備の機能要件・非機能要件
- [x] CLAUDE.md に v3 の情報が反映済みであること

Required deliverables (v4):
- [x] `docs/01_requirements/requirements_v4.md` — SQS + Lambda + EventBridge イベント駆動アーキテクチャの要件
- [x] CLAUDE.md に v4 の情報が反映済みであること

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

Required deliverables (v4):
- [ ] `docs/02_design/architecture_v4.md` — アーキテクチャ設計（SQS + Lambda + EventBridge）
- [ ] `docs/02_design/infrastructure_v4.md` — Terraform リソース設計（SQS, Lambda, EventBridge, VPC エンドポイント）
- [ ] `docs/02_design/cicd_v4.md` — CI/CD パイプライン設計（Lambda デプロイ追加）

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

Required deliverables (v4):
- [ ] `app/services/events.py` — SQS / EventBridge 送信サービス（boto3）
- [ ] `app/routers/tasks.py` — タスク作成・更新時のイベント発行コード追加
- [ ] `app/requirements.txt` — boto3 追加
- [ ] `lambda/task_created_handler.py` — SQS トリガー Lambda
- [ ] `lambda/task_completed_handler.py` — EventBridge トリガー Lambda
- [ ] `lambda/task_cleanup_handler.py` — Scheduler トリガー Lambda（VPC 内 RDS 接続）
- [ ] `infra/sqs.tf` — SQS キュー + DLQ
- [ ] `infra/lambda.tf` — Lambda 関数 3 つ
- [ ] `infra/eventbridge.tf` — EventBridge カスタムバス + ルール + Scheduler
- [ ] `infra/variables.tf` — v4 変数追加
- [ ] Code passes lint and Terraform validate

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

Required deliverables (v4):
- [ ] `docs/04_test/test_plan_v4.md` — テスト計画書（v4）
- [ ] `tests/test_tasks.py` — SQS / EventBridge 送信のモックテスト追加（moto 使用）
- [ ] v3 までの既存テストが引き続き全件 PASS

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

Required deliverables (v4):
- [ ] `docs/05_deploy/deploy_procedure_v4.md` — デプロイ手順書（v4）
- [ ] `docs/05_deploy/verification_v4.md` — 動作確認記録（v4）
- [ ] `terraform apply` で SQS / Lambda / EventBridge リソースが作成済み
- [ ] `POST /tasks` 実行後に Lambda ログ（CloudWatch Logs）でイベント受信を確認
- [ ] `PUT /tasks/{id}` で completed=true 更新後に Lambda ログで完了イベント受信を確認
- [ ] Scheduler による定期クリーンアップ Lambda の実行を確認

## Review Process

1. Read the CLAUDE.md to understand the current project state
2. Check if ALL required deliverables for the specified phase exist
3. Read each deliverable and verify it has substantive content (not just placeholders)
4. For code deliverables (Phase 3+), verify the code is syntactically valid
5. **For Phase 3, 4: run `/codex-review` on the changed code files and include the results in the output**
   - Phase 3: `app/` および `infra/` 配下の v3 変更ファイル
   - Phase 4: `tests/` 配下の v3 テストファイル
6. Output a checklist showing pass/fail for each item
7. If all items pass AND codex-review raises no blocking issues: declare the phase COMPLETE and recommend proceeding to the next phase
8. If any items fail or codex-review finds blocking issues: list what remains and do NOT approve phase completion

## Output Format

```
## Phase X Gate Review

| # | Deliverable | Status | Notes |
|---|------------|--------|-------|
| 1 | file/path  | PASS/FAIL | ... |

### Codex Review (Phase 3・4 のみ)
(codex-review の結果サマリ。ブロッキング指摘があれば FAIL とする)

### Result: PASS / FAIL
(Summary and recommendation)
```
