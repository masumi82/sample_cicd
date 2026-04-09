# 動作確認記録 v11 — 組織レベル Claude Code ベストプラクティス

## 概要

v11 デプロイ後の動作確認項目と結果を記録する。

## 確認項目

| # | 確認項目 | コマンド / 操作 | 期待結果 | 結果 |
|---|---------|---------------|---------|------|
| 1 | Hook テスト全件 PASS | `bash tests/test_hooks.sh` | 26 PASS / 0 FAIL | PASS — 26 PASS / 0 FAIL / 0 SKIP |
| 2 | 既存テスト回帰なし | `DATABASE_URL=sqlite:// pytest tests/ -v` | 84 passed | PASS — 84 passed in 2.30s |
| 3 | ruff lint PASS | `ruff check app/ tests/ lambda/` | All checks passed | PASS — All checks passed |
| 4 | .claudeignore 存在 | `test -f .claudeignore` | ファイルが存在 | PASS |
| 5 | settings.json 有効な JSON | `jq empty .claude/settings.json` | パース成功 | PASS |
| 6 | settings.json hooks 定義 | `jq '.hooks' .claude/settings.json` | PreToolUse + PostToolUse | PASS — 2 event types |
| 7 | settings.json deny ルール | `jq '.permissions.deny \| length' .claude/settings.json` | 7 | PASS — 7 deny rules |
| 8 | Hook: block-dangerous-git | `echo '{"tool_input":{"command":"git push --force"}}' \| .claude/hooks/block-dangerous-git.sh` | exit 2 | PASS — exit 2 |
| 9 | Hook: security-check (AKIA) | staged に AKIA キーを含む状態で実行 | exit 2 | PASS — TC-96 で検証済み |
| 10 | Hook: auto-format | `.py` ファイル編集後に実行 | ruff フォーマット適用 | PASS — TC-98 で検証済み |
| 11 | /team-onboard スキル認識 | Claude Code スキル一覧に表示 | `team-onboard` が表示 | PASS — スキル一覧に表示確認 |
| 12 | /pr-review スキル認識 | Claude Code スキル一覧に表示 | `pr-review` が表示 | PASS — スキル一覧に表示確認 |
| 13 | review-team-lead エージェント | `.claude/agents/review-team-lead.md` 存在 | ファイルが存在 | PASS |
| 14 | .gitignore に settings.local.json | `grep settings.local .gitignore` | マッチ | PASS |
| 15 | CLAUDE.md v11 行 | `grep v11 CLAUDE.md` | v11 行が存在 | PASS |
| 16 | CLAUDE.md Team Conventions | `grep 'Team Conventions' CLAUDE.md` | セクションが存在 | PASS |
| 17 | ガイド文書 | `test -f docs/guides/claude-code-team-guide_v11.md` | ファイルが存在 | PASS |

## 備考

- 2026-04-09 実施
- 全 17 項目 PASS
- v11 は AWS インフラ変更なし。CI パイプライン（ruff + pytest）のみで品質確認
- 手動検証（/team-onboard, /pr-review の実行）は Phase 5 のスキル検証で実施
