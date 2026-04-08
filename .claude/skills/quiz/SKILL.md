---
name: quiz
description: "Generate quiz questions from learning docs to test understanding. Usage: /quiz v7 or /quiz (random from all versions)"
user-invocable: true
---

# Quiz — 理解度チェック

学習ドキュメントから問題を生成し、理解度をテストする。

```
/quiz v7    → v7 の学習内容から出題
/quiz v6-v8 → v6〜v8 の範囲から出題
/quiz       → 全バージョンからランダム出題
```

All output must be in Japanese.

## 出題フロー

### 1. 問題ソースの読み込み
- `docs/06_learning/` 配下の対象バージョンの学習ドキュメントを読む
- `docs/01_requirements/requirements_vN.md` で学習テーマを把握
- `docs/02_design/` で設計判断の背景を把握

### 2. 問題タイプ（5種類からランダム）

#### Type A: 概念理解
```
Q: Cognito の SRP 認証とは何ですか？通常のパスワード認証と何が違いますか？
```

#### Type B: 設計判断
```
Q: v8 で ALB の HTTPS リスナーを削除した理由を説明してください。
```

#### Type C: トラブルシューティング
```
Q: terraform apply で「RepositoryNotEmptyException」が出ました。原因と対処法は？
```

#### Type D: コード穴埋め
```
Q: 以下の Terraform コードの ??? を埋めてください。
resource "aws_acm_certificate" "cloudfront" {
  provider = ???  # CloudFront 用 ACM のリージョン制約
  domain_name = "*.sample-cicd.click"
}
```

#### Type E: 比較・選択
```
Q: Terraform Remote State で S3 backend を使う利点を3つ挙げてください。
   ローカル state と比較して説明してください。
```

### 3. 出題と回答

1. 問題を 1 問ずつ表示
2. ユーザーの回答を待つ
3. 回答を評価（正解度 + 補足説明）
4. 5 問連続で出題（デフォルト）
5. 最後にスコアを表示:

```
## 結果
| # | 問題タイプ | トピック | 正解度 |
|---|-----------|---------|--------|
| 1 | 概念理解 | JWT 検証 | ○ |
| 2 | 設計判断 | HTTPS 終端 | △ |
| 3 | コード穴埋め | ACM provider | ○ |
| 4 | トラブル | Secrets Manager | ○ |
| 5 | 比較選択 | Remote State | ○ |

スコア: 4.5 / 5（90%）
```

### 4. 弱点フィードバック
- 間違えた問題の復習ポイントを提示
- 関連する学習ドキュメントのセクションを案内
