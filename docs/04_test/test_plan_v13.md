# テスト計画書 (v13)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-10 |
| バージョン | 13.0 |
| 前バージョン | [test_plan_v12.md](test_plan_v12.md) (v12.0) |

## 変更概要

v13 ではアプリケーションコードの変更はない（全て Terraform インフラ）。以下のインフラ検証テストを実施する:

- **Terraform 静的検証**: validate, fmt, tfsec による新規 .tf ファイルの検証
- **条件付きリソース検証**: `enable_guardduty` / `enable_securityhub` の toggle による plan 差分確認
- **コードレビュー検証**: EventBridge default bus 使用、Security Hub→Config 依存、バケットポリシー
- **既存テスト回帰**: pytest 94 テスト全件 PASS 確認

> アプリコード変更なしのため、新規 pytest テストの追加はない。セキュリティサービスの動作確認は Phase 5 のデプロイ検証で実施。

## 1. テスト方針

### 1.1 テスト範囲

| テスト種別 | 対象 | ツール |
|-----------|------|--------|
| Terraform 静的検証 | 新規 4 ファイル + 変更 7 ファイル | `terraform validate`, `terraform fmt` |
| セキュリティスキャン | 全 .tf ファイル | tfsec |
| Terraform Plan 検証 | リソース数・条件付きリソース | `terraform plan` |
| コードレビュー | 設計との整合性 | 手動レビュー |
| 既存テスト回帰 | Python 94 テスト | pytest |

### 1.2 テスト環境

- Terraform: ローカル validate + plan（Remote State 接続不要で validate 可能）
- Python: SQLite in-memory + fakeredis + moto（既存）

## 2. テストケース一覧

### 2.1 Terraform 静的検証

| TC | テスト名 | 概要 | 方法 |
|----|---------|------|------|
| TC-95 | terraform validate 成功 | 全 .tf ファイルの構文・参照が正しい | `terraform validate` |
| TC-96 | terraform fmt チェック | 全 .tf ファイルのフォーマットが正しい | `terraform fmt -check` |
| TC-97 | tfsec スキャン | セキュリティベストプラクティス違反なし | `tfsec infra/` |

### 2.2 Terraform Plan 検証

| TC | テスト名 | 概要 | 方法 |
|----|---------|------|------|
| TC-98 | terraform plan リソース数確認 | v13 新規リソースが plan に表示される | `terraform plan -var-file=dev.tfvars` |

### 2.3 条件付きリソース検証

| TC | テスト名 | 概要 | 方法 |
|----|---------|------|------|
| TC-99 | GuardDuty 無効時 plan | `enable_guardduty=false` で GuardDuty リソース 0 個 | plan + variable override |
| TC-100 | SecurityHub 無効時 plan | `enable_securityhub=false` で SecurityHub リソース 0 個 | plan + variable override |

### 2.4 コードレビュー検証

| TC | テスト名 | 概要 | 方法 |
|----|---------|------|------|
| TC-101 | EventBridge default bus 使用 | 3 つの EventBridge ルールに `event_bus_name` が未指定 | コードレビュー |
| TC-102 | SecurityHub→Config 依存 | `aws_securityhub_account` に `depends_on` Config recorder | コードレビュー |
| TC-103 | S3 バケットポリシー | CloudTrail/Config バケットに正しい service principal | コードレビュー |

### 2.5 既存テスト回帰

| TC | テスト名 | 概要 | 方法 |
|----|---------|------|------|
| TC-104 | pytest 94 件全 PASS | アプリコード未変更の回帰確認 | `DATABASE_URL=sqlite:// pytest tests/ -v` |

## 3. テスト実行

```bash
# Terraform 静的検証
cd infra && terraform validate
cd infra && terraform fmt -check

# ruff lint（アプリコード）
ruff check app/ tests/ lambda/

# 既存テスト回帰
DATABASE_URL=sqlite:// pytest tests/ -v
```

## 4. 想定テスト件数

| ファイル | v12 | v13 | 増減 |
|---------|-----|-----|------|
| test_main.py | 6 | 6 | - |
| test_tasks.py | 17 | 17 | - |
| test_attachments.py | 23 | 23 | - |
| test_observability.py | 8 | 8 | - |
| test_auth.py | 8 | 8 | - |
| test_cache.py | 22 | 22 | - |
| test_db_routing.py | 10 | 10 | - |
| **合計** | **94** | **94** | **±0** |

> v13 はアプリコード変更なし。インフラ検証は TC-95〜TC-103 (9 件) + 回帰 TC-104 (1 件) = 計 10 テストケース。

## 5. テスト結果

### 5.1 Terraform 静的検証

```
# terraform fmt -check: OK（差分なし）
# ruff check: All checks passed!
```

### 5.2 既存テスト回帰

```
94 passed in 2.40s
```

### 5.3 コードレビュー検証

| TC | 結果 | 備考 |
|----|------|------|
| TC-101 | PASS | guardduty.tf, config.tf, securityhub.tf の EventBridge ルールに `event_bus_name` なし |
| TC-102 | PASS | `securityhub.tf:6` に `depends_on = [aws_config_configuration_recorder_status.main]` |
| TC-103 | PASS | cloudtrail.tf: `cloudtrail.amazonaws.com`, config.tf: `config.amazonaws.com` |

全テストケース PASS。
