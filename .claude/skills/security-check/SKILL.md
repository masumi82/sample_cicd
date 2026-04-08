---
name: security-check
description: "Pre-commit security check. Scans staged changes for hardcoded AWS credentials, account IDs, resource identifiers, and other sensitive data. Run before every commit."
user-invocable: true
---

# Security Check (Pre-Commit)

コミット前のセキュリティチェックを実行する。`git diff --staged` の内容を分析し、機密情報の漏洩を防止する。

All output must be in Japanese.

## チェック対象

以下のパターンを `git diff --staged` の `+` 行（追加行）から検出する:

### 1. AWS アカウント ID
- パターン: 12桁の数字（`[0-9]{12}`）で `123456789012` 以外
- 置換先: `123456789012`

### 2. CloudFront ドメイン名
- パターン: `d[a-z0-9]{13,14}\.cloudfront\.net`
- 置換先: `dXXXXXXXXXXXXX.cloudfront.net`

### 3. Route 53 Hosted Zone ID
- パターン: `Z[A-Z0-9]{10,32}` で `Z0XXXXXXXXXXXXXXXXXX` 以外
- 置換先: `Z0XXXXXXXXXXXXXXXXXX`

### 4. Cognito User Pool ID
- パターン: `ap-northeast-1_[A-Za-z0-9]{9}`
- 置換先: `ap-northeast-1_XXXXXXXXX`

### 5. Cognito App Client ID
- パターン: 26文字の英数字（Cognito Client ID のフォーマット）
- 検出のみ（コンテキストで判断）

### 6. ALB DNS 名
- パターン: `sample-cicd-.*\.ap-northeast-1\.elb\.amazonaws\.com`
- 置換先: `sample-cicd-dev-alb-XXXXXXXXXX.ap-northeast-1.elb.amazonaws.com`

### 7. シークレット / API キー
- パターン: `AKIA[A-Z0-9]{16}` (AWS Access Key), `password\s*=\s*["'][^"']+["']`, `.env` ファイルの内容
- 検出時: **即座に警告、コミット中止を推奨**

### 8. Secrets Manager ARN
- パターン: `arn:aws:secretsmanager:.*:secret:.*` で実値
- 置換先: ARN のアカウント ID 部分を `123456789012` に

## 実行手順

1. `git diff --staged` を実行し、追加行を取得
2. 上記パターンでスキャン
3. 検出結果をテーブルで表示:

```
| # | ファイル | 行 | 検出パターン | 値 | 推奨アクション |
|---|---------|-----|------------|-----|-------------|
| 1 | infra/dev.tfvars | 42 | Hosted Zone ID | Z09... | Z0XXXXXXXXXXXXXXXXXX に置換 |
```

4. 検出なし → 「セキュリティチェック PASS。コミット可能です。」
5. 検出あり → 置換を提案し、ユーザーの確認後に `Edit` ツールで置換を実行

## 注意事項

- `docs/06_learning/` は `.gitignore` に含まれるためチェック対象外
- テストコードのダミー値（`TestPass123!` 等）は許容
- `123456789012`、`dXXXXXXXXXXXXX.cloudfront.net` 等のダミー値はスキップ
