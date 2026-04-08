---
name: learn
description: "Auto-generate learning document from version changes. Analyzes git diff, design decisions, and issues encountered. Usage: /learn v8"
user-invocable: true
---

# Learn — 学習ドキュメント自動生成

バージョンの変更内容から学習ドキュメントの下書きを自動生成する。

```
/learn v8   → v8 の学習ドキュメントを生成
/learn      → 最新バージョンを自動検出
```

All output must be in Japanese.

## 生成手順

### 1. 変更内容の収集
- `git log` で対象バージョンのコミットを特定（コミットメッセージの `vN:` プレフィックス）
- `git diff` で変更ファイル一覧と差分を取得
- `docs/01_requirements/requirements_vN.md` から学習テーマを抽出
- `docs/02_design/architecture_vN.md` から設計判断を抽出

### 2. 分析観点
以下の観点で変更を分析し、学びとして抽出する:

| 観点 | 内容 |
|------|------|
| **新しい AWS サービス** | 初めて使ったサービスの概要と設定ポイント |
| **設計判断** | なぜその方式を選んだか（代替案との比較） |
| **直面した課題** | エラー、予想外の挙動、ハマりポイント |
| **Terraform パターン** | 新しく学んだ HCL のイディオム |
| **CI/CD の変更** | パイプラインの拡張ポイント |
| **セキュリティ** | セキュリティ関連の学び |

### 3. 出力フォーマット

`docs/06_learning/YYYY-MM-DD_vN_learning.md` に以下の構造で生成:

```markdown
# 本日の学び (YYYY-MM-DD) — vN 実装を通じて

| 項目 | 内容 |
|------|------|
| 日付 | YYYY-MM-DD |
| 学習者 | m-horiuchi |
| テーマ | （requirements から抽出） |

---

## 1. トピックタイトル
### 概要
### コード例
### 教訓

## 2. ...

---

## まとめ — vN で学んだこと
### カテゴリ別要約
```

### 4. 生成後
- ユーザーにレビューを依頼
- 修正・追記の要望に対応
- 最終版を `docs/06_learning/` に保存

## 注意事項
- `docs/06_learning/` は `.gitignore` に含まれるためコミット対象外
- 過去の学習ドキュメント（`docs/06_learning/` 内）のフォーマットに合わせる
- 機密情報（AWS ID 等）は含めない
