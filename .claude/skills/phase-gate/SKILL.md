---
name: phase-gate
description: "Waterfall phase completion gate check. Use when completing a development phase to verify all deliverables are present and the phase is ready to close. Invoke with the phase number as argument, e.g. /phase-gate 1"
user-invocable: true
---

# Phase Gate Check

Perform a phase completion review for Phase `$ARGUMENTS` of the sample_cicd project.

All output must be in Japanese.

## Phase Definitions

> **Note**: v1 (Hello World API) と v2 (タスク管理 API + RDS) の両方の成果物を管理する。
> 引数が `1` の場合は v2 の Phase 1 をチェックする（v1 は完了済み）。

### Phase 1: Requirements (要件定義)
Required deliverables (v1):
- [x] `docs/01_requirements/requirements.md` — 機能要件・非機能要件
- [x] AWS構成の確定（CLAUDE.md に反映済みであること）

Required deliverables (v2):
- [ ] `docs/01_requirements/requirements_v2.md` — タスク管理 API + RDS の機能要件・非機能要件
- [ ] CLAUDE.md に v2 の情報が反映済みであること

### Phase 2: Design (設計)
Required deliverables (v1):
- [x] `docs/02_design/architecture.md` — アーキテクチャ設計（構成図含む）
- [x] `docs/02_design/api.md` — API設計（エンドポイント一覧）
- [x] `docs/02_design/cicd.md` — CI/CDパイプライン設計
- [x] `docs/02_design/infrastructure.md` — Terraform リソース設計

Required deliverables (v2):
- [ ] `docs/02_design/architecture_v2.md` — アーキテクチャ設計（RDS・プライベートサブネット追加）
- [ ] `docs/02_design/api_v2.md` — API設計（タスク CRUD エンドポイント）
- [ ] `docs/02_design/database.md` — DB設計（テーブル定義・マイグレーション戦略）
- [ ] `docs/02_design/infrastructure_v2.md` — Terraform リソース設計（+10 リソース）
- [ ] `docs/02_design/cicd_v2.md` — CI/CD パイプライン設計（変更点）

### Phase 3: Implementation (実装)
Required deliverables (v1):
- [x] `app/main.py` — FastAPI application
- [x] `app/Dockerfile` — Docker image definition
- [x] `app/requirements.txt` — Python dependencies
- [x] `infra/*.tf` — Terraform configuration files
- [x] `.github/workflows/ci-cd.yml` — GitHub Actions workflow

Required deliverables (v2):
- [ ] `app/database.py` — SQLAlchemy DB 接続設定
- [ ] `app/models.py` — SQLAlchemy ORM モデル
- [ ] `app/schemas.py` — Pydantic スキーマ
- [ ] `app/routers/tasks.py` — タスク CRUD ルーター
- [ ] `app/main.py` — ルーター追加（既存エンドポイント維持）
- [ ] `app/Dockerfile` — パッケージ構成対応
- [ ] `app/requirements.txt` — sqlalchemy, psycopg2-binary, alembic 追加
- [ ] `app/alembic.ini` + `app/alembic/` — マイグレーション設定
- [ ] `infra/rds.tf` — RDS PostgreSQL
- [ ] `infra/secrets.tf` — Secrets Manager
- [ ] `infra/main.tf` — プライベートサブネット追加
- [ ] `infra/security_groups.tf` — RDS 用 SG 追加
- [ ] `infra/iam.tf` — Secrets Manager 権限追加
- [ ] `infra/ecs.tf` — タスク定義に secrets ブロック追加
- [ ] `.github/workflows/ci-cd.yml` — Docker ビルドコンテキスト変更
- [ ] Code passes lint (ruff) and format checks

### Phase 4: Test (テスト)
Required deliverables (v1):
- [x] `docs/04_test/test_plan.md` — テスト計画書
- [x] `tests/test_main.py` — 6 テスト (TC-01〜TC-06)

Required deliverables (v2):
- [ ] `docs/04_test/test_plan_v2.md` — テスト計画書（v2）
- [ ] `tests/conftest.py` — テスト用 DB 設定（SQLite インメモリ）
- [ ] `tests/test_tasks.py` — タスク CRUD テスト (TC-07〜TC-18)
- [ ] All tests pass locally (既存 6 + 新規 12 = 18 テスト)
- [ ] CI pipeline runs tests successfully

### Phase 5: Deploy (デプロイ)
Required deliverables (v1):
- [x] `docs/05_deploy/deploy_procedure.md` — デプロイ手順書
- [x] `docs/05_deploy/verification.md` — 動作確認記録

Required deliverables (v2):
- [ ] `docs/05_deploy/deploy_procedure_v2.md` — デプロイ手順書（v2）
- [ ] `docs/05_deploy/verification_v2.md` — 動作確認記録（v2）
- [ ] RDS が正常稼働し tasks テーブルが存在する
- [ ] 全 CRUD エンドポイントが ALB 経由で動作する
- [ ] CI/CD pipeline deploys successfully on push

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
