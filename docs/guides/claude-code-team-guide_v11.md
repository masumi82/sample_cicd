# 組織向け Claude Code ベストプラクティスガイド (v11)

| 項目 | 内容 |
|------|------|
| 作成日 | 2026-04-09 |
| 対象読者 | Claude Code をチームに導入しようとしている開発リーダー |
| 前提 | Claude Code CLI の基本操作を理解していること |

---

## はじめに

このガイドは、個人で Claude Code を使っている開発者が **チームへの展開** を行う際のベストプラクティスをまとめたものです。

本プロジェクト（sample_cicd）で v1〜v10 を通じて蓄積した実践知をもとに、以下の 3 つの柱で構成しています:

| 柱 | テーマ | 解決する課題 |
|----|--------|------------|
| 1 | CLAUDE.md 設計パターン | 「何を AI に伝えるか」の標準化 |
| 2 | チーム開発ワークフロー | 「どう共同作業するか」の標準化 |
| 3 | Hooks・スキル・自動化 | 「どう品質を自動保証するか」の標準化 |

---

## 柱 1: CLAUDE.md 設計パターン

### 1.1 CLAUDE.md とは

CLAUDE.md は Claude Code がセッション開始時に自動で読み込むプロジェクト指示書です。ここに書かれた内容は Claude の全ての応答に影響します。

**重要**: CLAUDE.md は「AI への指示書」であると同時に「チームの暗黙知の形式知化」です。良い CLAUDE.md はチームメンバー（人間）にとっても有用なドキュメントになります。

### 1.2 3 層構造

Claude Code は CLAUDE.md を 3 つのレベルで読み込みます:

```
~/.claude/CLAUDE.md          ← グローバル（全プロジェクト共通）
./CLAUDE.md                  ← プロジェクト（リポジトリ固有）
./.claude/CLAUDE.md          ← チーム/サブディレクトリ（オプション）
```

#### グローバル CLAUDE.md に書くべきもの

**個人の作業スタイル・原則** — プロジェクトを問わず適用したいルール:

- ワークフロー（プランモード、サブエージェント戦略）
- セキュリティポリシー（秘密鍵の取り扱い、.env の保護）
- コミュニケーション言語（日本語 / 英語）
- Git ブランチ命名規則

```markdown
<!-- ~/.claude/CLAUDE.md の例 -->
## Security Policy
- NEVER hardcode API keys, tokens, passwords in source code
- Verify .env is in .gitignore BEFORE every commit

## Communication
- All communication in Japanese
- Source code and comments in English
```

#### プロジェクト CLAUDE.md に書くべきもの

**プロジェクト固有のコンテキスト** — このリポジトリで作業する全員が知るべき情報:

- アーキテクチャ概要（リクエストフロー、主要コンポーネント）
- よく使うコマンド（lint, test, build, deploy）
- 環境変数一覧（必須/オプション）
- コーディング規約（言語固有のルール）
- 設計判断と理由（なぜこの構成にしたか）

```markdown
<!-- ./CLAUDE.md の例 -->
## Architecture
Route 53 → CloudFront → API Gateway → ALB → ECS → RDS

## Common Commands
ruff check app/ tests/
DATABASE_URL=sqlite:// pytest tests/ -v
```

### 1.3 アンチパターン

| アンチパターン | 問題点 | 改善策 |
|--------------|--------|--------|
| CLAUDE.md に全てを詰め込む | 毎セッションの読み込み時間増大、焦点がぼやける | グローバルとプロジェクトに分離。教材はドキュメントに分離 |
| 実装の詳細を書く | コードと乖離して古くなる | 「何を」「なぜ」を書き、「どう」はコードに任せる |
| 規約を書かない | AI が毎回異なるスタイルでコードを生成 | 最低限のコーディング規約を明記 |
| 環境変数を書かない | AI が存在しない変数を参照してエラー | 必須/オプションの区分とデフォルト値を明記 |
| バージョン管理しない | チームメンバー間で CLAUDE.md が異なる | プロジェクト CLAUDE.md は必ず git 管理 |

### 1.4 メンテナンスのコツ

- **バージョンごとに更新**: 新機能追加時にアーキテクチャ図・環境変数・コマンドを更新
- **簡潔に保つ**: 200 行以下を目安。長くなったらセクションを別ドキュメントに分離
- **チームでレビュー**: CLAUDE.md の変更も PR でレビュー対象にする

---

## 柱 2: チーム開発ワークフロー

### 2.1 設定ファイルの共有戦略

Claude Code の設定ファイルは目的に応じて git 管理するものとしないものを分けます:

| ファイル | git 管理 | 目的 | 例 |
|---------|:---:|------|-----|
| `.claude/settings.json` | ✅ | チーム共有ルール | hooks, permissions.deny |
| `.claude/settings.local.json` | ✕ | 個人設定 | permissions.allow, MCP |
| `.claude/skills/*/SKILL.md` | ✅ | チーム共有スキル | /deploy, /security-check |
| `.claude/agents/*.md` | ✅ | チーム共有エージェント | review-team-lead |
| `.claudeignore` | ✅ | ファイル除外パターン | .env*, *.tfstate* |
| `CLAUDE.md` | ✅ | プロジェクト指示 | アーキテクチャ、コマンド |

**ポイント**: `settings.json`（共有）には hooks と deny ルールだけを置き、allow リストは `settings.local.json`（個人用）に置きます。これにより:
- 全員に同じセキュリティルールが適用される
- 個人の作業スタイル（使う AWS コマンド等）は自由に設定できる

### 2.2 `.claudeignore` の設計

`.claudeignore` は Claude がファイルを読む際の除外パターンです。`.gitignore` とは別物です:

```
.gitignore   → git が追跡しない（コミットされない）
.claudeignore → Claude が読み取らない（コンテキストに入らない）
```

**最低限入れるべきパターン:**

```
# 機密情報（Claude のコンテキストに秘密を入れない）
.env
.env.*
*.pem
*.key

# Terraform state（実リソース ID が含まれる）
*.tfstate
*.tfstate.backup
.terraform/

# 大量ファイル（コンテキストウィンドウの無駄遣い防止）
node_modules/
__pycache__/
```

### 2.3 ブランチ戦略

本プロジェクトでは以下のブランチ命名規則を使用:

```
VV-NN-description

VV = バージョン番号
NN = バージョン内連番（01, 02, ...）
description = 小文字ハイフン区切り

例: 11-01-requirements, 11-02-design, 11-03-implementation
```

**CI/CD との統合:**
```
ブランチ作業 → commit → push → PR 作成 → CI（自動） → レビュー → merge → CD（自動）
```

### 2.4 PR レビューフロー

Claude Code を使った PR レビューフローは以下の 3 層構造:

```
Layer 1: Claude Code Hooks（ローカル・自動）
  ↓ セキュリティチェック、フォーマット
Layer 2: /pr-review スキル（ローカル・手動）
  ↓ マルチエージェントレビュー
Layer 3: CI パイプライン（リモート・自動）
  ↓ lint, test, Trivy, tfsec, terraform plan
Layer 4: 人間レビュー（リモート・手動）
  ↓ 最終承認
```

各層の役割:
- **Hooks**: 明らかなミスを即座にキャッチ（秒単位のフィードバック）
- **/pr-review**: 設計・品質・規約の多角的レビュー（分単位）
- **CI**: 包括的な品質保証（分単位）
- **人間**: ビジネスロジック・アーキテクチャの最終判断

---

## 柱 3: Hooks・スキル・自動化

### 3.1 Hooks の基本

Hooks は Claude Code のツール実行前後に自動的にスクリプトを実行する仕組みです:

| フックタイプ | 発火タイミング | 主な用途 |
|------------|-------------|---------|
| PreToolUse | ツール実行前 | 危険操作のブロック、セキュリティチェック |
| PostToolUse | ツール実行後 | 自動フォーマット、ログ記録 |

#### exit code の意味

| exit code | 動作 |
|-----------|------|
| 0 | 許可（ツール実行を続行） |
| 1 | 警告（続行するが警告表示） |
| 2 | ブロック（ツール実行を中止） |

#### 設定例

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/security-check.sh"
          }
        ]
      }
    ]
  }
}
```

### 3.2 フックスクリプトの書き方

フックスクリプトは stdin で JSON を受け取ります:

```json
{
  "session_id": "...",
  "tool_name": "Bash",
  "tool_input": {
    "command": "git commit -m 'fix: something'"
  }
}
```

**テンプレート:**

```bash
#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)

# Extract tool input with jq
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

# Your check logic here
if [[ "$COMMAND" == *"dangerous-pattern"* ]]; then
  echo "Blocked: reason" >&2
  exit 2
fi

exit 0
```

**設計原則:**
1. **軽量に**: フックは毎回のツール実行で走る。重い処理は避ける
2. **Graceful degradation**: jq 未インストール時もエラーにしない
3. **独立ファイル**: テスト可能、PR レビュー可能
4. **stderr でメッセージ**: exit 2 の際、stderr にユーザーへのメッセージを出力

### 3.3 カスタムスキルの設計

スキルは `/command` 形式で呼び出せるカスタムコマンドです:

```markdown
---
name: my-skill
description: "What this skill does"
user-invocable: true
---

# Skill Title

実行手順を Markdown で記述。Claude はこの手順に従って実行する。
```

**スキル設計のベストプラクティス:**

| 原則 | 説明 | 例 |
|------|------|-----|
| 単一責務 | 1 スキル = 1 タスク | `/deploy` はデプロイだけ |
| 冪等性 | 何度実行しても同じ結果 | `/security-check` は何度でも安全 |
| 出力形式の固定 | テーブルやチェックリストで統一 | `/phase-gate` は必ずチェックリスト |
| Graceful degradation | 前提条件が欠けても動作 | ツール未インストール → スキップ |

**本プロジェクトのスキル一覧:**

| スキル | 用途 | 使用場面 |
|--------|------|---------|
| `/security-check` | コミット前機密スキャン | 毎コミット前（hooks で自動化済み） |
| `/deploy` | ワンコマンドデプロイ | デプロイ時 |
| `/phase-gate N` | フェーズ完了チェック | フェーズ完了時 |
| `/learn vN` | 学習文書自動生成 | バージョン完了時 |
| `/quiz vN` | 理解度クイズ | 学習確認時 |
| `/team-onboard` | オンボーディング | 新メンバー参加時 |
| `/pr-review` | マルチエージェントレビュー | PR 作成前 |
| `/cost-check` | AWS コスト確認 | 随時 |
| `/infra-cleanup` | インフラ削除 | 学習完了時 |

### 3.4 エージェント定義の設計

エージェントは特定の役割を持つ AI ペルソナです:

```markdown
---
name: review-team-lead
description: "Project-specific code reviewer"
tools:
  - Read
  - Grep
  - Glob
---

# Agent Instructions
レビュー観点と出力形式を定義...
```

**エージェント設計のポイント:**

1. **ツールを限定**: レビューエージェントは Read/Grep/Glob のみ（書き込み不可）
2. **観点を明確化**: チェックリスト形式でレビュー観点を列挙
3. **出力形式を固定**: Blockers / Suggestions / Good Points の 3 カテゴリ
4. **プロジェクト知識**: CLAUDE.md の規約を参照するよう指示

### 3.5 導入ロードマップ

チームに Claude Code を段階的に導入する推奨ステップ:

```
Phase 1（1 週目）: 基盤整備
  - プロジェクト CLAUDE.md を整備
  - .claudeignore を作成
  - .claude/settings.json で基本的な deny ルールを設定

Phase 2（2 週目）: Hooks 導入
  - security-check hook を有効化
  - block-dangerous-git hook を有効化
  - auto-format hook を有効化（Python プロジェクトの場合）

Phase 3（3 週目）: スキル展開
  - /team-onboard で全メンバーの環境を標準化
  - 頻繁な操作をスキルとして定義

Phase 4（4 週目〜）: レビュー統合
  - /pr-review でマルチエージェントレビューを開始
  - プロジェクト固有エージェントのチューニング
```

---

## チェックリスト: チーム導入前の確認事項

- [ ] プロジェクト CLAUDE.md にアーキテクチャ・コマンド・規約が記載されているか
- [ ] `.claudeignore` で機密ファイルが除外されているか
- [ ] `.claude/settings.json` に hooks と deny ルールが設定されているか
- [ ] `.claude/settings.json` が git 管理対象になっているか
- [ ] `.claude/settings.local.json` が `.gitignore` に含まれているか
- [ ] 全メンバーが `/team-onboard` でセットアップを完了したか
- [ ] PR レビューフロー（hooks → /pr-review → CI → 人間）が合意されているか

---

## 参考: 本プロジェクトの設定ファイル構成

```
sample_cicd/
├── .claudeignore                    # ファイル除外
├── .claude/
│   ├── settings.json                # チーム共有（hooks + deny）
│   ├── settings.local.json          # 個人用（gitignore）
│   ├── hooks/
│   │   ├── security-check.sh       # コミット時機密スキャン
│   │   ├── block-dangerous-git.sh  # 危険コマンドブロック
│   │   └── auto-format.sh          # ruff 自動フォーマット
│   ├── skills/
│   │   ├── security-check/         # 手動セキュリティチェック
│   │   ├── deploy/                 # デプロイ
│   │   ├── phase-gate/             # フェーズゲート
│   │   ├── learn/                  # 学習文書生成
│   │   ├── quiz/                   # クイズ
│   │   ├── cost-check/             # コスト確認
│   │   ├── infra-cleanup/          # インフラ削除
│   │   ├── team-onboard/           # オンボーディング
│   │   └── pr-review/              # マルチエージェントレビュー
│   └── agents/
│       └── review-team-lead.md     # プロジェクト固有レビュー
└── CLAUDE.md                        # プロジェクト指示書
```
