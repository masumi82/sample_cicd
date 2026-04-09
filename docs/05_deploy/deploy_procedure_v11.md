# デプロイ手順書 v11 — 組織レベル Claude Code ベストプラクティス

## 概要

v11 では以下をデプロイ（git コミット + PR）する:
- `.claudeignore`（ファイル除外パターン）
- `.claude/settings.json`（チーム共有 hooks + deny ルール）
- `.claude/hooks/`（セキュリティチェック・危険コマンドブロック・自動フォーマット）
- `.claude/skills/`（team-onboard, pr-review）
- `.claude/agents/`（review-team-lead）
- `docs/guides/claude-code-team-guide_v11.md`（ベストプラクティスガイド）
- `CLAUDE.md`（v11 行 + Team Conventions セクション）
- `.gitignore`（settings.local.json 追加）

> v11 は AWS インフラ変更なし。Terraform apply / CD パイプラインは不要。

## 前提条件

- v10 の全成果物が完成済み
- main ブランチが最新
- Phase 1〜4 の成果物がすべて作成済み

## 手順

### Step 1: 新規・変更ファイル確認

以下のファイルが存在することを確認:

| ファイル | 種別 |
|----------|------|
| `.claudeignore` | 新規 |
| `.claude/settings.json` | 新規 |
| `.claude/hooks/block-dangerous-git.sh` | 新規 |
| `.claude/hooks/security-check.sh` | 新規 |
| `.claude/hooks/auto-format.sh` | 新規 |
| `.claude/skills/team-onboard/SKILL.md` | 新規 |
| `.claude/skills/pr-review/SKILL.md` | 新規 |
| `.claude/agents/review-team-lead.md` | 新規 |
| `docs/guides/claude-code-team-guide_v11.md` | 新規 |
| `docs/01_requirements/requirements_v11.md` | 新規 |
| `docs/02_design/architecture_v11.md` | 新規 |
| `docs/02_design/infrastructure_v11.md` | 新規 |
| `docs/02_design/cicd_v11.md` | 新規 |
| `docs/04_test/test_plan_v11.md` | 新規 |
| `tests/test_hooks.sh` | 新規 |
| `CLAUDE.md` | 変更 |
| `.gitignore` | 変更 |

### Step 2: テスト実行

```bash
# Hook テスト
bash tests/test_hooks.sh

# 既存テスト回帰確認
DATABASE_URL=sqlite:// pytest tests/ -v

# Lint
ruff check app/ tests/ lambda/
```

全テスト PASS を確認。

### Step 3: セキュリティチェック

```bash
# /security-check スキルで staged changes を確認
git diff --staged
```

機密情報がないことを確認。

### Step 4: コミット + Push

```bash
git add .claudeignore .claude/settings.json .claude/hooks/ .claude/skills/team-onboard/ .claude/skills/pr-review/ .claude/agents/ docs/ tests/test_hooks.sh CLAUDE.md .gitignore
git commit -m "feat: add Claude Code team best practices (v11)"
git push origin 11-01-requirements
```

### Step 5: PR 作成 + CI 確認

```bash
gh pr create --title "feat: Claude Code team best practices (v11)" --body "..."
```

CI（ruff + pytest 84 テスト）が PASS することを確認。

### Step 6: マージ

CI PASS 後、main にマージ。

> v11 はアプリ / インフラ変更なしのため、CD ジョブ（terraform apply, ECR push, CodeDeploy 等）は実質スキップされる。

## 注意事項

- `.claude/settings.local.json` が `.gitignore` に含まれていることを確認（個人設定をコミットしない）
- hook スクリプトに実行権限（`chmod +x`）が付与されていることを確認
- `settings.json` の hooks パスが正しいことを確認（相対パス）
