---
name: phase-gate
description: "Waterfall phase completion gate check. Use when completing a development phase to verify all deliverables are present and the phase is ready to close. Invoke with the phase number as argument, e.g. /phase-gate 1"
user-invocable: true
---

# Phase Gate Check

Perform a phase completion review for Phase `$ARGUMENTS` of the sample_cicd project.

All output must be in Japanese.

## Phase Definitions

> **Note**: v1〜v3 の成果物を管理する。v1・v2 は完了済み。
> 引数が `1`〜`5` の場合は v3 のフェーズをチェックする。

### Phase 1: Requirements (要件定義)
Required deliverables (v1 & v2 — 完了済み):
- [x] `docs/01_requirements/requirements.md` — v1 機能要件・非機能要件
- [x] `docs/01_requirements/requirements_v2.md` — v2 タスク管理 API + RDS の要件
- [x] CLAUDE.md に v1・v2 の情報が反映済み

Required deliverables (v3):
- [ ] `docs/01_requirements/requirements_v3.md` — Auto Scaling + HTTPS準備の機能要件・非機能要件
- [ ] CLAUDE.md に v3 の情報が反映済みであること

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

Required deliverables (v3):
- [ ] `docs/02_design/architecture_v3.md` — アーキテクチャ設計（Auto Scaling + HTTPS準備）
- [ ] `docs/02_design/infrastructure_v3.md` — Terraform リソース設計（Auto Scaling + RDS Multi-AZ + HTTPS コード）
- [ ] `docs/02_design/cicd_v3.md` — CI/CD パイプライン設計（変更点。変更なしの場合はその旨を記載）

### Phase 3: Implementation (実装)
Required deliverables (v1 & v2 — 完了済み):
- [x] `app/main.py`, `app/database.py`, `app/models.py`, `app/schemas.py` — FastAPI + SQLAlchemy
- [x] `app/routers/tasks.py` — タスク CRUD ルーター
- [x] `app/Dockerfile`, `app/requirements.txt`, `app/alembic.ini`, `app/alembic/` — コンテナ・マイグレーション
- [x] `infra/*.tf` — v2 Terraform（RDS, Secrets Manager, プライベートサブネット含む）
- [x] `.github/workflows/ci-cd.yml` — CI/CD ワークフロー

Required deliverables (v3):
- [ ] `infra/autoscaling.tf` — Application Auto Scaling（ECS タスク数自動調整）
- [ ] `infra/rds.tf` — RDS Multi-AZ 対応（`multi_az = true` に変更）
- [ ] `infra/https.tf` — ACM + Route53 + ALB HTTPS リスナー（コードのみ、`enabled` 変数で制御）
- [ ] `infra/variables.tf` — Auto Scaling 設定変数追加（min/max タスク数, CPU 目標値）
- [ ] アプリケーションコードの変更なし（Terraform のみ）
- [ ] Code passes lint and Terraform validate

### Phase 4: Test (テスト)
Required deliverables (v1 & v2 — 完了済み):
- [x] `docs/04_test/test_plan.md` — v1 テスト計画書
- [x] `tests/test_main.py` — 6 テスト (TC-01〜TC-06)
- [x] `docs/04_test/test_plan_v2.md` — v2 テスト計画書
- [x] `tests/conftest.py`, `tests/test_tasks.py` — v2 CRUD テスト

Required deliverables (v3):
- [ ] `docs/04_test/test_plan_v3.md` — テスト計画書（v3）
- [ ] v2 までの既存テストが引き続き全件 PASS
- [ ] Auto Scaling 動作確認手順が test_plan_v3.md に記載済み

### Phase 5: Deploy (デプロイ)
Required deliverables (v1 & v2 — 完了済み):
- [x] `docs/05_deploy/deploy_procedure.md`, `docs/05_deploy/verification.md` — v1
- [x] `docs/05_deploy/deploy_procedure_v2.md`, `docs/05_deploy/verification_v2.md` — v2

Required deliverables (v3):
- [ ] `docs/05_deploy/deploy_procedure_v3.md` — デプロイ手順書（v3）
- [ ] `docs/05_deploy/verification_v3.md` — 動作確認記録（v3）
- [ ] `terraform apply` で Auto Scaling リソースが作成済み
- [ ] RDS Multi-AZ が有効化済み
- [ ] ECS タスク数が CPU 負荷に応じて増減することを確認

## Review Process

1. Read the CLAUDE.md to understand the current project state
2. Check if ALL required deliverables for the specified phase exist
3. Read each deliverable and verify it has substantive content (not just placeholders)
4. For code deliverables (Phase 3+), verify the code is syntactically valid
5. Output a checklist showing pass/fail for each item
6. If all items pass: declare the phase COMPLETE and recommend proceeding to the next phase
7. If any items fail: list what remains and do NOT approve phase completion

## Output Format

```
## Phase X Gate Review

| # | Deliverable | Status | Notes |
|---|------------|--------|-------|
| 1 | file/path  | PASS/FAIL | ... |

### Result: PASS / FAIL
(Summary and recommendation)
```
