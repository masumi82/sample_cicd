---
name: pr-review
description: "Multi-agent parallel PR review. Launches review-senior, review-qa, and review-team-lead agents to produce a unified review report."
user-invocable: true
---

# PR Review (Multi-Agent)

現在のブランチの変更を 3 つのレビューエージェントで並列にレビューし、統合レポートを生成する。

All output must be in Japanese.

## 実行手順

### 1. 変更差分の取得

```bash
git diff main...HEAD
```

変更がない場合は「レビュー対象の変更がありません」と表示して終了。

### 2. 変更ファイルの一覧取得

```bash
git diff --name-only main...HEAD
```

### 3. マルチエージェントレビュー

以下の 3 エージェントを **並列** で起動する（Agent ツールを 1 メッセージで 3 回呼び出し）:

#### エージェント 1: review-senior
- **サブエージェントタイプ**: `review-senior`
- **観点**: コード品質、設計パターン、可読性、パフォーマンス、保守性
- **プロンプト**: 変更差分と変更ファイル一覧を渡し、上記観点でレビューを依頼

#### エージェント 2: review-qa
- **サブエージェントタイプ**: `review-qa`
- **観点**: テストカバレッジ、エッジケース、回帰リスク、エラーハンドリング、障害シナリオ
- **プロンプト**: 変更差分と変更ファイル一覧を渡し、上記観点でレビューを依頼

#### エージェント 3: review-team-lead
- **サブエージェントタイプ**: `review-team-lead`（エージェント定義は `.claude/agents/review-team-lead.md`）
- **観点**: プロジェクト固有規約の遵守（セキュリティ、命名、言語、ドキュメント整合性）
- **プロンプト**: 変更差分と変更ファイル一覧を渡し、プロジェクト CLAUDE.md の規約に照らしてレビューを依頼。`.claude/agents/review-team-lead.md` の内容を読んでプロンプトに含めること

### 4. 統合レポートの生成

3 エージェントの結果を以下の形式で統合:

```
## PR Review Report

### 変更概要
- ブランチ: {current branch}
- 変更ファイル数: {N} files
- 変更行数: +{additions} / -{deletions}

### 🔴 Blockers（マージ前に修正必須）
(セキュリティ問題、重大なバグ、規約違反等。なければ「なし」)

### 🟡 Suggestions（改善推奨）
(コード品質、テスト追加、パフォーマンス改善等)

### 🟢 Good Points（良い点）
(設計判断、テスト網羅性、規約遵守等)

### レビュー詳細
#### Senior Engineer Review
(review-senior の結果サマリー)

#### QA Engineer Review
(review-qa の結果サマリー)

#### Team Lead Review
(review-team-lead の結果サマリー)
```

## 注意事項

- 3 エージェントは必ず並列起動すること（1 メッセージに 3 つの Agent ツール呼び出し）
- 各エージェントには変更差分の全文を渡すこと（サマリーではなく）
- Blockers がある場合は冒頭で明確に警告すること
- レビュー結果は日本語で出力すること
