---
name: cost-check
description: "Check AWS costs. Shows daily/monthly breakdown by service, alerts on unexpected charges. Usage: /cost-check or /cost-check 7 (last N days)"
user-invocable: true
---

# Cost Check

AWS のコストを確認する。サービス別の日次/月次コストを表示し、想定外の課金を警告する。

```
/cost-check      → 直近 7 日間のコスト
/cost-check 30   → 直近 30 日間のコスト
```

All output must be in Japanese.

## 実行手順

### 1. 期間別コスト取得
```bash
aws ce get-cost-and-usage \
  --time-period Start=$(date -d "$DAYS days ago" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --region us-east-1
```

### 2. 出力フォーマット

#### サービス別コスト（期間合計）
```
| サービス | コスト | 割合 |
|---------|--------|------|
| RDS | $X.XX | XX% |
| ECS | $X.XX | XX% |
| CloudFront | $X.XX | XX% |
| ... | ... | ... |
| **合計** | **$X.XX** | |
```

#### 日別推移（直近 7 日）
```
| 日付 | コスト |
|------|--------|
| 2026-04-08 | $X.XX |
| ... | ... |
```

### 3. 警告ルール
- 1 日あたり $5 以上: **警告** — インフラが起動中の可能性
- 1 日あたり $0.50 以下: 正常（インフラ停止中）
- 新しいサービスの課金: **注意** — 意図しないリソースの可能性

### 4. コスト削減提案
- RDS が高い → `terraform destroy` でインフラ停止を提案
- NAT Gateway が課金 → 不要なら削除を提案
- CloudFront の転送量 → 学習用なら問題なし
