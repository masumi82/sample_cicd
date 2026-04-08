---
name: phase-gate
description: "Waterfall phase completion gate check. Use when completing a development phase to verify all deliverables are present and the phase is ready to close. Invoke with the phase number as argument, e.g. /phase-gate 1"
user-invocable: true
---

# Phase Gate Check

Perform a phase completion review for Phase `$ARGUMENTS` of the sample_cicd project.

All output must be in Japanese.

## Phase Definitions

> **Note**: v1〜v8 は完了済み（成果物は `docs/` 配下を参照）。
> 引数が `1`〜`5` の場合は **最新開発中バージョン** のフェーズをチェックする。
> 最新バージョンは CLAUDE.md のバージョンテーブルで確認すること。

### 完了済みバージョン一覧

| Version | Phase 1 | Phase 2 | Phase 3 | Phase 4 | Phase 5 |
|---------|---------|---------|---------|---------|---------|
| v1 & v2 | [x] | [x] | [x] | [x] | [x] |
| v3 | [x] | [x] | [x] | [x] | [x] |
| v4 | [x] | [x] | [x] | [x] | [x] |
| v5 | [x] | [x] | [x] | [x] | [x] |
| v6 | [x] | [x] | [x] | [x] | [x] |
| v7 | [x] | [x] | [x] | [x] | [x] |
| v8 | [x] | [x] | [x] | [x] | [x] |

### 開発中: v9 — CI/CD 完全自動化 + セキュリティスキャン

v9 固有の成果物（テンプレートに加えて確認）:
- Phase 3: `infra/codedeploy.tf`, OIDC provider, 2nd TG, CI/CD ワークフロー分割 (ci.yml + cd.yml)
- Phase 5: CodeDeploy B/G 動作確認, OIDC 認証確認, Trivy/tfsec スキャン結果, terraform plan PR コメント, Infracost PR コメント

### 各フェーズの必須成果物パターン（新バージョン用テンプレート）

#### Phase 1: Requirements (要件定義)
- [ ] `docs/01_requirements/requirements_vN.md` — 機能要件・非機能要件
- [ ] CLAUDE.md にバージョン情報が反映済み

#### Phase 2: Design (設計)
- [ ] `docs/02_design/architecture_vN.md` — アーキテクチャ設計
- [ ] `docs/02_design/infrastructure_vN.md` — Terraform リソース設計
- [ ] `docs/02_design/cicd_vN.md` — CI/CD パイプライン設計
- [ ] API 変更がある場合: `docs/02_design/api_vN.md`

#### Phase 3: Implementation (実装)
- [ ] 設計書に記載された全ファイルが作成・変更済み
- [ ] Code passes lint (`ruff check app/ tests/ lambda/`)
- [ ] Terraform validate 成功
- [ ] Frontend builds successfully (`cd frontend && npm ci && npm run build`)

#### Phase 4: Test (テスト)
- [ ] `docs/04_test/test_plan_vN.md` — テスト計画書
- [ ] 新規テストコード（アプリ変更がある場合）
- [ ] 既存テスト全件 PASS

#### Phase 5: Deploy (デプロイ)
- [ ] `docs/05_deploy/deploy_procedure_vN.md` — デプロイ手順書
- [ ] `docs/05_deploy/verification_vN.md` — 動作確認記録（全項目 PASS）
- [ ] `terraform apply` 成功
- [ ] CI/CD パイプライン成功
- [ ] 動作確認（curl / ブラウザ / Playwright MCP）

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
