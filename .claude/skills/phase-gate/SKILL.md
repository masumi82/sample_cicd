---
name: phase-gate
description: "Waterfall phase completion gate check. Use when completing a development phase to verify all deliverables are present and the phase is ready to close. Invoke with the phase number as argument, e.g. /phase-gate 1"
user-invocable: true
---

# Phase Gate Check

Perform a phase completion review for Phase `$ARGUMENTS` of the sample_cicd project.

All output must be in Japanese.

## Phase Definitions

### Phase 1: Requirements (要件定義)
Required deliverables:
- [ ] `docs/01_requirements/requirements.md` — 機能要件・非機能要件
- [ ] AWS構成の確定（CLAUDE.md に反映済みであること）

### Phase 2: Design (設計)
Required deliverables:
- [ ] `docs/02_design/architecture.md` — アーキテクチャ設計（構成図含む）
- [ ] `docs/02_design/api.md` — API設計（エンドポイント一覧）
- [ ] `docs/02_design/cicd.md` — CI/CDパイプライン設計
- [ ] `docs/02_design/infrastructure.md` — Terraform リソース設計

### Phase 3: Implementation (実装)
Required deliverables:
- [ ] `app/main.py` — FastAPI application
- [ ] `app/Dockerfile` — Docker image definition
- [ ] `app/requirements.txt` — Python dependencies
- [ ] `infra/*.tf` — Terraform configuration files
- [ ] `.github/workflows/ci-cd.yml` — GitHub Actions workflow
- [ ] Code passes lint (ruff) and format checks

### Phase 4: Test (テスト)
Required deliverables:
- [ ] `docs/04_test/test_plan.md` — テスト計画書
- [ ] `tests/` — pytest test files
- [ ] All tests pass locally
- [ ] CI pipeline runs tests successfully

### Phase 5: Deploy (デプロイ)
Required deliverables:
- [ ] `docs/05_deploy/deploy_procedure.md` — デプロイ手順書
- [ ] `docs/05_deploy/verification.md` — 動作確認記録
- [ ] Application accessible via ALB endpoint
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
