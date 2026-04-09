# テスト計画書 (v11)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-09 |
| バージョン | 11.0 |
| 前バージョン | [test_plan_v10.md](test_plan_v10.md) (v10.0) |

## 変更概要

v11 ではアプリケーションコードへの変更はない。Claude Code の設定ファイル（hooks, skills, agents, .claudeignore）を追加したため、以下のテストを実施する:

- **Hook スクリプトテスト**: 3 本の bash hook スクリプトの動作検証（自動テスト）
- **設定ファイル検証**: `.claude/settings.json`, `.claudeignore` の構文・内容確認
- **スキル手動検証**: `/team-onboard`, `/pr-review` の実行確認
- **既存テスト回帰確認**: 84 テストが引き続き PASS

> v11 はアプリ / インフラ変更なし。pytest による新規テストは `tests/test_hooks.sh`（bash テスト）として追加。

## 1. テスト方針

### 1.1 テスト範囲

| テスト種別 | 対象 | ツール | 方法 |
|-----------|------|--------|------|
| 単体テスト | hook スクリプト 3 本 | bash + jq | 自動（`tests/test_hooks.sh`） |
| 構文検証 | `.claude/settings.json` | jq / python | 自動 |
| パターン検証 | `.claudeignore` | bash | 自動 |
| 機能テスト | `/team-onboard` スキル | Claude Code CLI | 手動 |
| 機能テスト | `/pr-review` スキル | Claude Code CLI | 手動 |
| 回帰テスト | 既存 84 テスト | pytest | 自動 |

### 1.2 テスト環境

- Shell: bash
- JSON パーサー: jq
- Python テスト: pytest + SQLite in-memory + moto + fakeredis（既存）

## 2. テストケース一覧

### 2.1 block-dangerous-git.sh（PreToolUse Hook）

| TC | テスト名 | 入力 | 期待結果 |
|----|---------|------|---------|
| TC-85 | `test_blocks_git_push_force` | `{"tool_input":{"command":"git push --force origin main"}}` | exit 2（ブロック） |
| TC-86 | `test_blocks_git_push_f` | `{"tool_input":{"command":"git push -f origin main"}}` | exit 2（ブロック） |
| TC-87 | `test_blocks_git_reset_hard` | `{"tool_input":{"command":"git reset --hard HEAD~1"}}` | exit 2（ブロック） |
| TC-88 | `test_blocks_rm_rf` | `{"tool_input":{"command":"rm -rf /tmp/test"}}` | exit 2（ブロック） |
| TC-89 | `test_allows_git_status` | `{"tool_input":{"command":"git status"}}` | exit 0（許可） |
| TC-90 | `test_allows_git_push_normal` | `{"tool_input":{"command":"git push origin feature"}}` | exit 0（許可） |
| TC-91 | `test_allows_empty_input` | `{}` | exit 0（許可） |

### 2.2 security-check.sh（PreToolUse Hook）

| TC | テスト名 | 概要 | 期待結果 |
|----|---------|------|---------|
| TC-92 | `test_skips_non_commit_commands` | `git status` コマンドではスキャンしない | exit 0 |
| TC-93 | `test_allows_dummy_account_id` | staged に `123456789012` のみ含む | exit 0 |
| TC-94 | `test_detects_cloudfront_domain` | staged に実 CloudFront ドメイン含む | exit 2 |
| TC-95 | `test_allows_dummy_cloudfront` | staged に `dXXXXXXXXXXXXX.cloudfront.net` のみ | exit 0 |
| TC-96 | `test_detects_aws_access_key` | staged に `AKIAIOSFODNN7EXAMPLE` 含む | exit 2 |
| TC-97 | `test_allows_clean_commit` | staged に機密情報なし | exit 0 |

### 2.3 auto-format.sh（PostToolUse Hook）

| TC | テスト名 | 概要 | 期待結果 |
|----|---------|------|---------|
| TC-98 | `test_formats_python_file` | `.py` ファイル編集後に ruff 実行 | exit 0、ファイルがフォーマット済み |
| TC-99 | `test_skips_non_python_file` | `.tf` ファイル編集では何もしない | exit 0 |
| TC-100 | `test_skips_empty_input` | file_path なし | exit 0 |

### 2.4 設定ファイル検証

| TC | テスト名 | 概要 | 期待結果 |
|----|---------|------|---------|
| TC-101 | `test_settings_json_valid` | `.claude/settings.json` が有効な JSON | jq パース成功 |
| TC-102 | `test_settings_has_hooks` | hooks セクションが存在 | PreToolUse + PostToolUse |
| TC-103 | `test_settings_has_deny` | permissions.deny が存在 | 7 パターン |
| TC-104 | `test_claudeignore_exists` | `.claudeignore` が存在し空でない | ファイルサイズ > 0 |
| TC-105 | `test_claudeignore_has_env` | `.env` パターンが含まれる | grep 成功 |
| TC-106 | `test_claudeignore_has_tfstate` | `*.tfstate` パターンが含まれる | grep 成功 |

### 2.5 回帰テスト

| TC | テスト名 | 概要 | 期待結果 |
|----|---------|------|---------|
| TC-107 | `test_existing_tests_pass` | 既存 84 テスト全件 PASS | 84 passed |
| TC-108 | `test_ruff_lint_pass` | ruff check 全件 PASS | All checks passed |

### 2.6 手動検証（Phase 5 で実施）

| TC | テスト名 | 概要 | 方法 |
|----|---------|------|------|
| TC-109 | `/team-onboard` 動作 | チェックリストが日本語で出力される | Claude Code CLI で実行 |
| TC-110 | `/pr-review` 動作 | 3 エージェントが並列起動し統合レポート生成 | ブランチ上で実行 |
| TC-111 | Hook 統合動作 | ファイル編集→auto-format→commit→security-check の一連フロー | Claude Code セッションで実行 |

## 3. テスト実行方法

### 3.1 自動テスト

```bash
# Hook テスト
bash tests/test_hooks.sh

# 既存テスト（回帰確認）
DATABASE_URL=sqlite:// pytest tests/ -v

# Lint
ruff check app/ tests/ lambda/
```

### 3.2 手動テスト

```bash
# Claude Code CLI でスキル実行
# /team-onboard
# /pr-review
```

## 4. 合格基準

- `tests/test_hooks.sh` 全テストケース PASS
- 既存 pytest 84 テスト全件 PASS
- ruff lint All checks passed
- 手動検証 3 件 PASS（Phase 5 で実施）
