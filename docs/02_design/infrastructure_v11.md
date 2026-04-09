# インフラストラクチャ設計書 (v11)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-09 |
| バージョン | 11.0 |
| 前バージョン | [infrastructure_v10.md](infrastructure_v10.md) (v10.0) |

## 変更概要

v11 では AWS インフラ（Terraform リソース）への変更はない。代わりに **Claude Code 設定ファイル群** を新規作成・変更する:

- **新規ファイル**: 8 ファイル（`.claudeignore`、hooks 3 本、`settings.json`、スキル 2 本、エージェント 1 本）
- **変更ファイル**: 2 ファイル（`CLAUDE.md`、`phase-gate/SKILL.md`）
- **新規ディレクトリ**: 4 ディレクトリ（`.claude/hooks/`、`.claude/skills/team-onboard/`、`.claude/skills/pr-review/`、`.claude/agents/`）
- **ドキュメント**: 1 ファイル（`docs/guides/claude-code-team-guide_v11.md`）
- **テスト**: 1 ファイル（`tests/test_hooks.sh`）

## 1. ファイル変更マトリクス

### 1.1 新規ファイル

| # | ファイルパス | 種別 | 説明 | git 管理 |
|---|------------|------|------|:---:|
| 1 | `.claudeignore` | 設定 | Claude Code ファイル除外パターン | ✅ |
| 2 | `.claude/settings.json` | 設定 | チーム共有 hooks + deny ルール | ✅ |
| 3 | `.claude/hooks/security-check.sh` | スクリプト | PreToolUse: コミット時機密スキャン | ✅ |
| 4 | `.claude/hooks/block-dangerous-git.sh` | スクリプト | PreToolUse: 危険 git コマンドブロック | ✅ |
| 5 | `.claude/hooks/auto-format.sh` | スクリプト | PostToolUse: ruff 自動フォーマット | ✅ |
| 6 | `.claude/skills/team-onboard/SKILL.md` | スキル | 新メンバーオンボーディング | ✅ |
| 7 | `.claude/skills/pr-review/SKILL.md` | スキル | マルチエージェント PR レビュー | ✅ |
| 8 | `.claude/agents/review-team-lead.md` | エージェント | プロジェクト固有レビュー | ✅ |

### 1.2 変更ファイル

| # | ファイルパス | 変更内容 |
|---|------------|---------|
| 9 | `CLAUDE.md` | バージョンテーブルに v11 行追加（済）+ Team Conventions セクション追加 |
| 10 | `.claude/skills/phase-gate/SKILL.md` | v10 完了マーク + v11 固有成果物リスト追加 |

### 1.3 ドキュメント

| # | ファイルパス | 説明 |
|---|------------|------|
| 11 | `docs/guides/claude-code-team-guide_v11.md` | 組織向け Claude Code ベストプラクティスガイド |
| 12 | `tests/test_hooks.sh` | hook スクリプトの自動テスト |

## 2. 各ファイルの詳細設計

### 2.1 `.claudeignore`

**場所**: プロジェクトルート
**構文**: `.gitignore` と同じパターン構文
**サイズ**: 約 20 行

```
# Secrets and credentials
.env
.env.*
*.pem
*.key

# Terraform state (contains real AWS resource IDs)
*.tfstate
*.tfstate.backup
.terraform/

# Build artifacts and dependencies
node_modules/
__pycache__/
.venv/
frontend/dist/

# Binary files (not useful for Claude context)
*.png
*.jpg
*.gif
*.zip
```

### 2.2 `.claude/settings.json`

**場所**: `.claude/settings.json`（チーム共有、git 管理対象）
**既存との関係**: `.claude/settings.local.json`（個人用）は変更なし。settings.json → settings.local.json の順で読み込まれ、後者が優先

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/block-dangerous-git.sh"
          },
          {
            "type": "command",
            "command": ".claude/hooks/security-check.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/auto-format.sh"
          }
        ]
      }
    ]
  },
  "permissions": {
    "deny": [
      "Bash(rm -rf *)",
      "Bash(git push --force*)",
      "Bash(git reset --hard*)",
      "Bash(git clean -f*)",
      "Edit(*.env*)",
      "Edit(*.pem)",
      "Edit(*.key)"
    ]
  }
}
```

### 2.3 `.claude/hooks/security-check.sh`

**トリガー**: PreToolUse / Bash マッチャー
**条件**: `git commit` コマンドの場合のみ実行
**処理**: `git diff --staged` の追加行を機密パターンでスキャン
**exit code**: 0（安全）/ 2（機密検出、ブロック）

検出パターン（既存 `/security-check` スキルから移植）:

| # | パターン | 正規表現 | 許可値（ダミー） |
|---|---------|---------|----------------|
| 1 | AWS アカウント ID | `[0-9]{12}` | `123456789012` |
| 2 | CloudFront ドメイン | `d[a-z0-9]{13,14}\.cloudfront\.net` | `dXXXXXXXXXXXXX.cloudfront.net` |
| 3 | Hosted Zone ID | `Z[A-Z0-9]{10,32}` | `Z0XXXXXXXXXXXXXXXXXX` |
| 4 | Cognito User Pool ID | `ap-northeast-1_[A-Za-z0-9]{9}` | `ap-northeast-1_XXXXXXXXX` |
| 5 | AWS Access Key | `AKIA[A-Z0-9]{16}` | （検出時即ブロック） |
| 6 | ALB DNS 名 | `sample-cicd-.*\.ap-northeast-1\.elb\.amazonaws\.com` | ダミー DNS |

### 2.4 `.claude/hooks/block-dangerous-git.sh`

**トリガー**: PreToolUse / Bash マッチャー
**処理**: コマンド文字列を解析し、危険パターンにマッチしたらブロック

ブロック対象:

| # | パターン | 理由 |
|---|---------|------|
| 1 | `git push --force` / `git push -f` | リモート履歴の破壊 |
| 2 | `git reset --hard` | ローカル変更の消失 |
| 3 | `git clean -f` | 未追跡ファイルの削除 |
| 4 | `rm -rf` | ファイルの一括削除 |
| 5 | `git checkout -- .` / `git restore .` | 全変更の破棄 |

### 2.5 `.claude/hooks/auto-format.sh`

**トリガー**: PostToolUse / `Edit|Write` マッチャー
**条件**: 変更対象が `.py` ファイルの場合のみ実行
**処理**: `ruff check --fix <file> && ruff format <file>`
**Graceful degradation**: ruff 未インストール時は何もせず exit 0

### 2.6 `.claude/skills/team-onboard/SKILL.md`

**SKILL.md フロントマター:**

```yaml
---
name: team-onboard
description: "New team member Claude Code setup checklist. Checks global CLAUDE.md, project conventions, hooks, required tools, and .claudeignore."
user-invocable: true
---
```

**出力形式**: 日本語チェックリスト（✅ / ❌ 付き）

### 2.7 `.claude/skills/pr-review/SKILL.md`

**SKILL.md フロントマター:**

```yaml
---
name: pr-review
description: "Multi-agent parallel PR review. Launches review-senior, review-qa, and review-team-lead agents to produce a unified review report."
user-invocable: true
---
```

**エージェント構成:**

| エージェント | 種別 | 観点 |
|------------|------|------|
| `review-senior` | グローバル | コード品質、設計パターン、可読性、パフォーマンス |
| `review-qa` | グローバル | テストカバレッジ、エッジケース、回帰リスク、エラーハンドリング |
| `review-team-lead` | プロジェクト | プロジェクト固有規約（セキュリティ、命名、ドキュメント） |

### 2.8 `.claude/agents/review-team-lead.md`

**配置**: `.claude/agents/`（プロジェクトレベル）
**ツール**: Read, Grep, Glob（読み取り専用）

**レビュー観点:**

| # | 観点 | チェック内容 |
|---|------|------------|
| 1 | セキュリティ | AWS アカウント ID、CloudFront ドメイン等のハードコード |
| 2 | 命名規約 | Python: PEP 8、Terraform: snake_case、タグ付け |
| 3 | 言語規約 | ユーザー向け出力は日本語、コード・コメントは英語 |
| 4 | ドキュメント | CLAUDE.md との整合性、バージョン情報の反映 |
| 5 | Graceful degradation | 環境変数未設定時のフォールバック実装 |

## 3. ディレクトリ構造（変更後）

```
sample_cicd/
├── .claudeignore                          # v11 新規
├── .claude/
│   ├── settings.json                      # v11 新規（チーム共有）
│   ├── settings.local.json                # 既存（個人用、変更なし）
│   ├── hooks/                             # v11 新規ディレクトリ
│   │   ├── security-check.sh
│   │   ├── block-dangerous-git.sh
│   │   └── auto-format.sh
│   ├── skills/
│   │   ├── security-check/SKILL.md        # 既存
│   │   ├── deploy/SKILL.md                # 既存
│   │   ├── learn/SKILL.md                 # 既存
│   │   ├── phase-gate/SKILL.md            # 変更
│   │   ├── quiz/SKILL.md                  # 既存
│   │   ├── cost-check/SKILL.md            # 既存
│   │   ├── infra-cleanup/SKILL.md         # 既存
│   │   ├── team-onboard/SKILL.md          # v11 新規
│   │   └── pr-review/SKILL.md             # v11 新規
│   └── agents/                            # v11 新規ディレクトリ
│       └── review-team-lead.md
├── CLAUDE.md                              # 変更
├── docs/
│   └── guides/
│       └── claude-code-team-guide_v11.md  # v11 新規
└── tests/
    └── test_hooks.sh                      # v11 新規
```

## 4. Terraform リソース（変更なし）

v11 では Terraform リソースへの追加・変更・削除はない。

v10 時点のアクティブリソース: **約 122 リソース**（dev 環境）

詳細は [infrastructure_v10.md](infrastructure_v10.md) を参照。
