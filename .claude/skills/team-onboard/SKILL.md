---
name: team-onboard
description: "New team member Claude Code environment setup checklist. Verifies global CLAUDE.md, project conventions, hooks, required tools, and .claudeignore."
user-invocable: true
---

# Team Onboarding Check

新しいチームメンバーの Claude Code 環境セットアップ状態をチェックし、チェックリストを出力する。

All output must be in Japanese.

## チェック項目

以下の項目を順にチェックし、結果を ✅ / ❌ で表示する。

### 1. グローバル CLAUDE.md

- `~/.claude/CLAUDE.md` の存在確認
- 存在する場合: ファイルサイズと主要セクション（Workflow, Security, Communication）の有無を確認
- 存在しない場合: 作成を推奨し、プロジェクトの CLAUDE.md を参考にするよう案内

### 2. プロジェクト CLAUDE.md の理解

- プロジェクトルートの `CLAUDE.md` を読み取り、以下の主要規約をサマリーとして表示:
  - 言語規約（ユーザー向け日本語、コード英語）
  - セキュリティ規約（機密情報のマスクルール）
  - コーディング規約（PEP 8, snake_case, type hints）
  - ブランチ命名規則（`VV-NN-description`）
  - 開発プロセス（ウォーターフォール、/phase-gate）

### 3. Hooks の動作確認

- `.claude/settings.json` の存在確認
- `hooks` セクションの存在確認
- 定義されているフック一覧を表示:
  - PreToolUse: block-dangerous-git.sh, security-check.sh
  - PostToolUse: auto-format.sh
- 各フックスクリプトの存在と実行権限の確認

### 4. 必要ツールの確認

以下のツールがインストールされているか確認:

| ツール | 確認コマンド | 用途 |
|--------|------------|------|
| `ruff` | `ruff --version` | Python lint/format（auto-format hook で使用） |
| `pytest` | `pytest --version` | テスト実行 |
| `terraform` | `terraform --version` | IaC |
| `docker` | `docker --version` | コンテナビルド |
| `jq` | `jq --version` | hook スクリプトの JSON パース |

### 5. `.claudeignore` の確認

- `.claudeignore` ファイルの存在確認
- 主要な除外パターン（`.env*`, `*.tfstate*`, `node_modules/`）が含まれているか確認

### 6. 個人設定の確認

- `.claude/settings.local.json` の存在確認（個人用設定）
- `permissions.allow` セクションの有無

## 出力形式

```
## Claude Code チームオンボーディングチェック

| # | 項目 | ステータス | 備考 |
|---|------|-----------|------|
| 1 | グローバル CLAUDE.md | ✅ / ❌ | ... |
| 2 | プロジェクト規約の理解 | ✅ | 主要規約サマリー |
| 3 | Hooks 設定 | ✅ / ❌ | フック N 個有効 |
| 4 | 必要ツール | ✅ / ❌ | 未インストール: ... |
| 5 | .claudeignore | ✅ / ❌ | ... |
| 6 | 個人設定 | ✅ / ❌ | ... |

### 推奨アクション
(❌ の項目に対する具体的な修正手順を記載)
```
