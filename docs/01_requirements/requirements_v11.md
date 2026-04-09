# 要件定義書 (v11)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-09 |
| バージョン | 11.0 |
| 前バージョン | [requirements_v10.md](requirements_v10.md) (v10.0) |

## 変更概要

v10（API Gateway + ElastiCache Redis + レート制限）に以下を追加する:

- **Claude Code Hooks**: PreToolUse / PostToolUse フックによるセキュリティチェック・自動フォーマット・危険コマンドブロックの自動化
- **`.claudeignore`**: 機密ファイル・Terraform state・ビルド成果物の Claude 読み取り除外
- **チーム共有設定**: `.claude/settings.json`（git 管理）によるチーム統一の hooks・deny ルール
- **新スキル・エージェント**: `/team-onboard`（オンボーディング）、`/pr-review`（マルチエージェントレビュー）、`review-team-lead` エージェント
- **ベストプラクティスガイド**: 組織で Claude Code を活用するための包括的ガイド文書

## 1. プロジェクト概要

### 1.1 目的

v10 までで CI/CD パイプラインとインフラの構築が完了した。しかし開発ツールとしての Claude Code 活用面に以下の課題がある:

1. **セキュリティチェックが手動**: `/security-check` スキルは存在するが、コミット前に手動で実行する必要がある。フック自動化されておらず、実行忘れのリスクがある
2. **機密ファイルの読み取り制御なし**: `.claudeignore` が未作成で、`*.tfstate`（実 AWS リソース ID を含む）や `.env` ファイルを Claude が読み取り可能な状態
3. **チーム共有設定がない**: `.claude/settings.local.json`（個人用・gitignore 対象）のみ存在し、`.claude/settings.json`（チーム共有・git 管理）がない。新メンバー参加時に設定の標準化ができない
4. **オンボーディングプロセスの不在**: 新しいチームメンバーが Claude Code を使い始める際のガイドやセットアップ支援がない
5. **コードレビューの属人化**: レビューエージェントは存在するが、プロジェクト固有の規約を理解したレビューフローが未確立

v11 ではこれらを解決し、チームで Claude Code を効果的に活用するためのベストプラクティスを学習する。

### 1.2 学習目標

| # | 学習テーマ | 内容 | 実装 |
|---|-----------|------|:---:|
| 1 | Claude Code Hooks | PreToolUse / PostToolUse フックの仕組み、matcher 設定、exit code によるブロック制御 | ✅ |
| 2 | `.claudeignore` | ファイル除外パターンの設計、`.gitignore` との違い、セキュリティ上の意義 | ✅ |
| 3 | チーム共有設定 | `settings.json`（共有）vs `settings.local.json`（個人）の使い分け、permissions.deny の設計 | ✅ |
| 4 | カスタムスキル設計 | SKILL.md の構造、user-invocable スキルの作成、サブエージェント連携パターン | ✅ |
| 5 | エージェント定義 | プロジェクト固有エージェントの設計、レビューペルソナの作成 | ✅ |
| 6 | CLAUDE.md 設計パターン | グローバル vs プロジェクトレベルの役割分担、チーム向けテンプレート設計 | ✅ |
| 7 | オンボーディング自動化 | 新メンバーの環境セットアップを支援するスキルの設計・実装 | ✅ |
| 8 | マルチエージェントレビュー | 複数エージェントを並列起動して統合レビューを行うスキルの設計・実装 | ✅ |

### 1.3 スコープ

**スコープ内:**

- Claude Code Hooks
  - PreToolUse: `Bash` ツール使用前のセキュリティチェック（`git commit` 時に staged changes の機密スキャン）
  - PreToolUse: `Bash` ツール使用前の危険コマンドブロック（`git push --force`, `rm -rf` 等）
  - PostToolUse: `Edit` / `Write` ツール使用後の Python 自動フォーマット（ruff）
  - hook スクリプトの独立ファイル化（テスト可能・レビュー可能）
- `.claudeignore`
  - 機密ファイル（`.env*`, `*.pem`, `*.key`）
  - Terraform state（`*.tfstate*`, `.terraform/`）
  - ビルド成果物（`node_modules/`, `__pycache__/`, `frontend/dist/`）
  - バイナリファイル（`*.png`, `*.jpg`, `*.gif`, `*.zip`）
- チーム共有設定（`.claude/settings.json`）
  - hooks セクション（上記フック定義）
  - permissions.deny（危険操作のブロック）
  - git 管理対象（チーム全員に適用）
- カスタムスキル
  - `/team-onboard`: 新メンバー環境セットアップチェックリスト
  - `/pr-review`: マルチエージェント並列 PR レビュー
- エージェント定義
  - `review-team-lead.md`: プロジェクト固有規約を理解したレビューエージェント
- ドキュメント
  - チーム向けベストプラクティスガイド（`docs/guides/claude-code-team-guide_v11.md`）
  - CLAUDE.md への Team Conventions セクション追加
- テスト
  - hook スクリプトの bash テスト（`tests/test_hooks.sh`）
  - スキルの手動実行検証

**スコープ外:**

- MCP サーバー設定（具体的なチームツール要件がない段階では実践的でない）
- Teams 機能（`~/.claude/teams/`）の設定（実験的機能のため安定するまで待機）
- git hooks（`.git/hooks/`）との連携（Claude Code hooks で十分）
- IDE 拡張の設定（VS Code, JetBrains の Claude Code プラグイン設定）
- アプリケーションコード（`app/`）の変更（v11 はツール設定のみ）
- Terraform / AWS インフラの変更

## 2. 機能要件

### 既存（v10 から継続）

| ID | 概要 | 変更 |
|----|------|------|
| FR-1 | Hello World API (`GET /`) | なし |
| FR-2 | ヘルスチェック (`GET /health`) | なし |
| FR-3 | CI パイプライン | なし |
| FR-4 | CD パイプライン | なし |
| FR-5〜FR-9 | タスク CRUD API | なし |
| FR-10 | データベース永続化 | なし |
| FR-11 | ECS Auto Scaling | なし |
| FR-12〜FR-14 | イベント駆動処理 | なし |
| FR-15〜FR-18 | 添付ファイル CRUD API | なし |
| FR-19 | マルチ環境管理 | なし |
| FR-20〜FR-24 | Observability | なし |
| FR-25〜FR-29 | Web UI | なし |
| FR-30 | CORS ミドルウェア | なし |
| FR-31 | フロントエンド CI/CD | なし |
| FR-32〜FR-38 | Cognito 認証 | なし |
| FR-39〜FR-40 | WAF | なし |
| FR-41〜FR-47 | HTTPS + カスタムドメイン + Remote State | なし |
| FR-48 | CodeDeploy B/G デプロイ | なし |
| FR-49〜FR-50 | セキュリティスキャン (Trivy, tfsec) | なし |
| FR-51 | OIDC 認証 | なし |
| FR-52 | Terraform CI/CD | なし |
| FR-53 | Infracost | なし |
| FR-54〜FR-55 | Environments + ワークフロー分割 | なし |
| FR-56〜FR-58 | API Gateway (REST API, Cache, Usage Plans) | なし |
| FR-59〜FR-60 | ElastiCache Redis + Cache-aside | なし |
| FR-61 | CloudFront オリジン変更 | なし |
| FR-62 | モニタリング拡張 | なし |

### 新規

#### FR-63: Claude Code Hooks

| 項目 | 内容 |
|------|------|
| ID | FR-63 |
| 概要 | Claude Code の hooks 機能を使い、ツール実行前後に自動チェックを実行する |
| PreToolUse Hook 1 | **セキュリティチェック** — `Bash` ツールで `git commit` 実行時、`git diff --staged` を分析して機密情報（AWS アカウント ID、CloudFront ドメイン、Hosted Zone ID、AKIA キー等）を検出。検出時は exit 2 でブロック |
| PreToolUse Hook 2 | **危険コマンドブロック** — `Bash` ツールで `git push --force`, `git reset --hard`, `git clean -f`, `rm -rf` を検出して exit 2 でブロック |
| PostToolUse Hook | **自動フォーマット** — `Edit` / `Write` ツールで `.py` ファイル変更後、`ruff check --fix` + `ruff format` を自動実行 |
| スクリプト配置 | `.claude/hooks/security-check.sh`, `.claude/hooks/block-dangerous-git.sh`, `.claude/hooks/auto-format.sh` |
| exit code | 0 = 許可、2 = ブロック（Claude にツール実行を中止させる） |
| 参照 | 既存 `/security-check` スキル（`.claude/skills/security-check/SKILL.md`）のパターンを bash 化 |

#### FR-64: `.claudeignore`

| 項目 | 内容 |
|------|------|
| ID | FR-64 |
| 概要 | Claude Code がファイルを読み取る際の除外パターンを定義する |
| ファイル | プロジェクトルートの `.claudeignore` |
| 除外対象: 機密 | `.env`, `.env.*`, `*.pem`, `*.key` |
| 除外対象: Terraform | `*.tfstate`, `*.tfstate.backup`, `.terraform/` |
| 除外対象: ビルド | `node_modules/`, `__pycache__/`, `.venv/`, `frontend/dist/` |
| 除外対象: バイナリ | `*.png`, `*.jpg`, `*.gif`, `*.zip` |
| `.gitignore` との違い | `.gitignore` は git の追跡対象を制御。`.claudeignore` は Claude の読み取り対象を制御。両方必要 |

#### FR-65: チーム共有設定

| 項目 | 内容 |
|------|------|
| ID | FR-65 |
| 概要 | `.claude/settings.json` をチーム共有設定として git 管理し、hooks と deny ルールを標準化する |
| ファイル | `.claude/settings.json`（新規、git 管理対象） |
| hooks | FR-63 で定義した 3 つのフックを設定 |
| permissions.deny | `Bash(rm -rf *)`, `Bash(git push --force*)`, `Bash(git reset --hard*)`, `Bash(git clean -f*)`, `Edit(*.env*)`, `Edit(*.pem)`, `Edit(*.key)` |
| 既存との関係 | `.claude/settings.local.json`（個人用、gitignore 対象）は継続使用。`settings.json` が先に読まれ、`settings.local.json` で個人用オーバーライド |

#### FR-66: `/team-onboard` スキル

| 項目 | 内容 |
|------|------|
| ID | FR-66 |
| 概要 | 新しいチームメンバーの Claude Code 環境セットアップを支援するスキル |
| ファイル | `.claude/skills/team-onboard/SKILL.md` |
| user-invocable | `true`（`/team-onboard` で実行可能） |
| チェック項目 1 | `~/.claude/CLAUDE.md` の存在確認 |
| チェック項目 2 | プロジェクト CLAUDE.md の主要規約サマリー表示 |
| チェック項目 3 | hooks の有効状態確認（`.claude/settings.json` の hooks セクション） |
| チェック項目 4 | 必要ツールの確認（ruff, pytest, terraform, docker） |
| チェック項目 5 | `.claudeignore` の存在確認 |
| 出力 | 日本語チェックリスト（✅ / ❌ 付き） |

#### FR-67: `/pr-review` スキル

| 項目 | 内容 |
|------|------|
| ID | FR-67 |
| 概要 | 複数のレビューエージェントを並列起動し、統合 PR レビューレポートを生成するスキル |
| ファイル | `.claude/skills/pr-review/SKILL.md` |
| user-invocable | `true`（`/pr-review` で実行可能） |
| 入力 | `git diff main...HEAD` で取得した変更差分 |
| エージェント 1 | `review-senior`（コード品質・設計パターン・可読性） |
| エージェント 2 | `review-qa`（テストカバレッジ・エッジケース・エラーハンドリング） |
| エージェント 3 | `review-team-lead`（プロジェクト固有規約の遵守、FR-68 で定義） |
| 出力 | 統合レビューレポート（ブロッカー / 提案 / 良い点の 3 カテゴリ） |

#### FR-68: `review-team-lead` エージェント

| 項目 | 内容 |
|------|------|
| ID | FR-68 |
| 概要 | プロジェクト固有の規約を理解したレビューエージェントを定義する |
| ファイル | `.claude/agents/review-team-lead.md` |
| 知識範囲 | プロジェクト CLAUDE.md の全規約、AWS クレデンシャルマスクルール、Terraform 命名規則、ウォーターフォールプロセス |
| レビュー観点 | セキュリティ（機密情報の漏洩）、規約遵守（命名・構造・コメント言語）、ドキュメント整合性 |
| ツール | Read, Grep, Glob（読み取り専用） |

#### FR-69: ベストプラクティスガイド文書

| 項目 | 内容 |
|------|------|
| ID | FR-69 |
| 概要 | 組織で Claude Code を活用するための包括的ベストプラクティスガイドを作成する |
| ファイル | `docs/guides/claude-code-team-guide_v11.md` |
| 柱 1 | CLAUDE.md 設計パターン（グローバル vs プロジェクト、テンプレート、アンチパターン） |
| 柱 2 | チーム開発ワークフロー（設定共有、ブランチ戦略、レビューフロー、`.claudeignore`） |
| 柱 3 | Hooks・スキル・自動化（フックタイプ、スキル設計、エージェント設計） |
| 対象読者 | Claude Code をチームに導入しようとしている開発リーダー |

#### FR-70: CLAUDE.md 更新

| 項目 | 内容 |
|------|------|
| ID | FR-70 |
| 概要 | プロジェクト CLAUDE.md に v11 情報と Team Conventions セクションを追加する |
| バージョンテーブル | v11 行の追加（テーマ: 組織レベル Claude Code ベストプラクティス） |
| Team Conventions | hooks の説明、`.claudeignore` ポリシー、PR レビューワークフロー、ブランチ命名規則の参照 |

## 3. 非機能要件

### 既存（v10 から継続）

| ID | 概要 | 変更 |
|----|------|------|
| NFR-1 | 可用性 | なし |
| NFR-2 | セキュリティ | **向上**（hooks による自動チェック、`.claudeignore` による読み取り制御） |
| NFR-3 | パフォーマンス | なし |
| NFR-4 | 運用性 | **向上**（オンボーディング自動化、レビュー標準化） |
| NFR-5 | コスト | なし |
| NFR-6 | スケーラビリティ | なし |
| NFR-7 | 疎結合性 | なし |
| NFR-8 | コンテンツ配信 | なし |
| NFR-9 | 可観測性 | なし |
| NFR-10 | 認証・認可 | なし |
| NFR-11 | DNS・ドメイン管理 | なし |
| NFR-12 | デプロイ戦略 | なし |
| NFR-13 | CI/CD セキュリティ | なし |
| NFR-14 | API 管理 | なし |
| NFR-15 | キャッシュ耐障害性 | なし |

### 変更・追加

#### NFR-2: セキュリティ（更新）

| 項目 | 内容 |
|------|------|
| ID | NFR-2 |
| Claude Code hooks | PreToolUse フックで機密情報の自動スキャン・ブロック。手動実行忘れのリスクを排除 |
| ファイル読み取り制御 | `.claudeignore` で `*.tfstate`、`.env*` 等の機密ファイルを Claude の読み取り対象から除外 |
| 危険コマンド防止 | PreToolUse フックで `git push --force`、`rm -rf` 等の危険コマンドをブロック |
| チーム統一 | `.claude/settings.json`（git 管理）で全メンバーに同一のセキュリティルールを適用 |

#### NFR-16: 開発者体験（新規）

| 項目 | 内容 |
|------|------|
| ID | NFR-16 |
| オンボーディング | `/team-onboard` スキルで新メンバーの環境セットアップを 5 分以内に完了可能 |
| コードレビュー | `/pr-review` スキルで 3 エージェント並列レビューを 1 コマンドで実行 |
| 自動フォーマット | PostToolUse フックで Python コードの自動 ruff フォーマット。手動実行不要 |
| ガイド文書 | 包括的ベストプラクティスガイドでチーム全体の Claude Code 活用レベルを底上げ |

## 4. 技術スタック

v11 は AWS インフラの変更がないため、技術スタックの追加はなし。

| カテゴリ | 技術 | 用途 |
|----------|------|------|
| Claude Code Hooks | bash scripts | PreToolUse / PostToolUse の自動チェック |
| Claude Code Skills | SKILL.md (Markdown) | `/team-onboard`, `/pr-review` カスタムスキル |
| Claude Code Agents | Agent .md (Markdown) | `review-team-lead` プロジェクト固有エージェント |
| Lint / Format | ruff | PostToolUse フックから呼び出し |

## 5. コスト見積もり

v11 は Claude Code の設定変更のみ。AWS リソースの追加・変更なし。

| 項目 | 月額 |
|------|------|
| 既存インフラ（v10 まで） | 約 $126〜128 |
| v11 追加分 | $0（設定ファイルのみ） |
| **v11 全体合計** | **約 $126〜128/月（変更なし）** |

## 6. 前提条件・制約

### 前提条件

- v10 の全成果物が完成済みであること
- Claude Code CLI がインストールされていること
- ruff がインストールされていること（PostToolUse フックで使用）
- bash が使用可能であること（hook スクリプト実行に必要）

### 制約

- Claude Code hooks は CLI 経由でのみ動作する（IDE 拡張での動作は未検証）
- `.claudeignore` のパターンは Claude Code 固有であり、他の AI ツールとは共有できない
- `settings.json`（チーム共有）と `settings.local.json`（個人用）の優先順位は Claude Code のバージョンに依存する
- hook スクリプトの実行時間が長いと Claude Code の応答性に影響する（軽量な実装が必要）
- `/pr-review` スキルはマルチエージェント起動のため API コストが通常の 3 倍以上になる可能性がある

## 7. 実装方針

### 7.1 設定ファイル階層

```
設定の優先順位（下ほど高い）:

~/.claude/CLAUDE.md              ← 全プロジェクト共通原則
~/.claude/settings.json          ← グローバル権限・サンドボックス
.claude/settings.json            ← チーム共有設定（git 管理）  ← v11 新規
.claude/settings.local.json      ← 個人設定（gitignore 対象）  ← 既存
./CLAUDE.md                      ← プロジェクト固有コンテキスト
```

### 7.2 ファイル構成の変更

```
sample_cicd/
  .claudeignore                         # 新規: ファイル除外パターン
  .claude/
    settings.json                       # 新規: チーム共有設定（hooks + deny）
    settings.local.json                 # 既存: 個人設定（変更なし）
    hooks/
      security-check.sh                # 新規: PreToolUse セキュリティ
      block-dangerous-git.sh           # 新規: PreToolUse 危険コマンド
      auto-format.sh                   # 新規: PostToolUse ruff フォーマット
    skills/
      team-onboard/SKILL.md            # 新規: オンボーディング
      pr-review/SKILL.md               # 新規: マルチエージェントレビュー
      (既存 7 スキルは変更なし)
    agents/
      review-team-lead.md              # 新規: プロジェクト固有レビュー
  docs/
    guides/
      claude-code-team-guide_v11.md    # 新規: ベストプラクティスガイド
  CLAUDE.md                            # 変更: v11 行 + Team Conventions
  tests/
    test_hooks.sh                      # 新規: hook テスト
```

### 7.3 3 つの柱

| 柱 | テーマ | 対応 FR |
|----|--------|---------|
| 1 | CLAUDE.md 設計パターン | FR-69, FR-70 |
| 2 | チーム開発ワークフロー | FR-64, FR-65, FR-67, FR-68 |
| 3 | Hooks・スキル・自動化 | FR-63, FR-66 |

## 8. 用語集（v11 追加分）

| 用語 | 説明 |
|------|------|
| Claude Code Hooks | Claude Code のツール実行前後に自動的にスクリプトを実行する仕組み。PreToolUse（実行前）と PostToolUse（実行後）がある |
| PreToolUse | ツール実行前に発火するフック。exit 2 を返すとツール実行をブロックできる |
| PostToolUse | ツール実行後に発火するフック。自動フォーマットやログ記録に使用 |
| `.claudeignore` | Claude Code がファイルを読み取る際の除外パターンを定義するファイル。`.gitignore` と似た構文だが、用途が異なる |
| `settings.json` | Claude Code のプロジェクトレベル設定ファイル。git 管理対象で、チーム全員に同一設定を適用 |
| `settings.local.json` | Claude Code の個人設定ファイル。gitignore 対象で、個人の好みや環境固有の設定を保存 |
| SKILL.md | Claude Code のカスタムスキルを定義するファイル。`user-invocable: true` でスラッシュコマンドとして実行可能 |
| matcher | hooks 設定でフックを発火させるツール名のパターン。正規表現で指定可能（例: `Edit\|Write`） |
| マルチエージェントレビュー | 複数のエージェントを並列起動し、それぞれの観点（品質・QA・規約）でレビューを行う手法 |
| Graceful degradation | hooks やスキルで使用する外部ツール（ruff 等）が未インストールの場合、エラーではなく機能をスキップする設計 |
