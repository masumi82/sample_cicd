# デプロイ手順書 (v13) — セキュリティ監視 + コンプライアンス

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-10 |
| バージョン | 13.0 |
| 前バージョン | [deploy_procedure_v12.md](deploy_procedure_v12.md) (v12.0) |

## 概要

v13 では以下のセキュリティ監視リソースをデプロイする:

- CloudTrail 証跡 + 専用 S3 バケット + CloudWatch Logs
- GuardDuty Detector（条件付き）
- AWS Config Recorder + 10 マネージドルール + 専用 S3 バケット
- Security Hub + CIS/FSBP 標準（条件付き、Config 依存）
- EventBridge ルール 3 つ → 既存 SNS トピック
- SNS トピックポリシー（EventBridge publish 許可）
- ダッシュボード Row 9（セキュリティウィジェット）
- OIDC IAM 権限追加

> **アプリケーションコードの変更なし**。ECS タスク定義、Lambda、Frontend の再デプロイは不要。

## 前提条件

- v12 の全リソースがデプロイ済みであること
- Terraform Remote State (S3 + DynamoDB) がアクセス可能であること
- OIDC IAM ロールに `cloudtrail:*`, `guardduty:*`, `config:*`, `securityhub:*` 権限が含まれていること
- AWS アカウントで GuardDuty / Config / Security Hub が未有効化であること（既に有効化済みの場合は `terraform import` が必要）

## デプロイ手順

### Step 1: Terraform ファイル確認

| 種別 | ファイル | 内容 |
|------|---------|------|
| 新規 | `infra/cloudtrail.tf` | CloudTrail Trail + S3 + IAM + CW Logs |
| 新規 | `infra/guardduty.tf` | GuardDuty Detector + EventBridge→SNS |
| 新規 | `infra/config.tf` | Config Recorder + 10 Rules + S3 + EventBridge→SNS |
| 新規 | `infra/securityhub.tf` | Security Hub + CIS/FSBP + EventBridge→SNS |
| 変更 | `infra/variables.tf` | v13 変数 4 個追加 |
| 変更 | `infra/dev.tfvars` | v13 値追加 |
| 変更 | `infra/prod.tfvars` | v13 値追加 |
| 変更 | `infra/oidc.tf` | 4 サービス権限追加 |
| 変更 | `infra/sns.tf` | SNS トピックポリシー追加 |
| 変更 | `infra/monitoring.tf` | Dashboard Row 9 追加 |
| 変更 | `infra/outputs.tf` | 3 出力値追加 |
| 変更 | `infra/main.tf` | `data.aws_caller_identity` 追加 |

### Step 2: Terraform Plan

```bash
cd infra
terraform workspace select dev
terraform plan -var-file=dev.tfvars
```

期待結果: 約 25〜35 リソースの追加（CloudTrail S3 関連 6, CloudTrail 本体 3, Config 関連 15, GuardDuty 3, Security Hub 5, SNS ポリシー 1, Dashboard 変更）

### Step 3: Terraform Apply（CI/CD パイプライン経由）

PR をマージして CD パイプラインで自動実行:

```bash
# PR → CI (lint, test, plan) → merge → CD (apply)
```

または手動実行:

```bash
terraform apply -var-file=dev.tfvars
```

### Step 4: デプロイ結果確認

```bash
# CloudTrail 確認
aws cloudtrail get-trail-status --name sample-cicd-dev-trail

# GuardDuty 確認
aws guardduty list-detectors

# Config 確認
aws configservice describe-configuration-recorder-status

# Security Hub 確認
aws securityhub get-enabled-standards

# Config Rules 確認
aws configservice describe-compliance-by-config-rule
```

### Step 5: 動作確認

`docs/05_deploy/verification_v13.md` の全項目を実施。

## prod 環境での追加手順

prod 環境では dev と同じ手順を実行:

```bash
terraform workspace select prod
terraform plan -var-file=prod.tfvars
terraform apply -var-file=prod.tfvars
```

prod 固有の確認事項:
- CloudTrail ログ保持期間が 365 日であること
- GuardDuty / Security Hub が有効であること

## トラブルシューティング

### CloudTrail 作成失敗: InsufficientS3BucketPolicyException

原因: S3 バケットポリシーが Trail 作成前に適用されていない。
対処: `depends_on = [aws_s3_bucket_policy.cloudtrail_logs]` が設定されていることを確認。手動の場合は `terraform apply` を再実行。

### Config Recorder 開始失敗: InsufficientDeliveryPolicyException

原因: Config の S3 配信先バケットポリシーが不足。
対処: `aws_s3_bucket_policy.config` が正しい `config.amazonaws.com` principal を含んでいることを確認。

### Security Hub 有効化失敗: Config not enabled

原因: Security Hub は Config Recorder が有効であることが前提条件。
対処: `depends_on = [aws_config_configuration_recorder_status.main]` を確認。

### OIDC 権限エラー: AccessDeniedException

原因: GitHub Actions の OIDC ロールにセキュリティサービスの権限が不足。
対処: `oidc.tf` に `cloudtrail:*`, `guardduty:*`, `config:*`, `securityhub:*` が追加されていることを確認。

### GuardDuty 既に有効化済み: BadRequestException

原因: AWS アカウントで既に GuardDuty が手動で有効化されている。
対処: `terraform import aws_guardduty_detector.main[0] <detector-id>` で既存リソースをインポート。

### Config Recorder 既に存在: MaxNumberOfConfigurationRecordersExceededException

原因: リージョンに Config Recorder は 1 つしか作成できない。
対処: `terraform import aws_config_configuration_recorder.main <recorder-name>` でインポート。

## コスト影響

| 項目 | 追加月額 |
|------|---------|
| CloudTrail (第1証跡・管理イベント) | $0 |
| CloudTrail S3 ログストレージ | ~$0.50 |
| CloudTrail CloudWatch Logs | ~$0.50 |
| AWS Config (Recorder + 10 Rules) | ~$2-3 |
| GuardDuty (30日無料後) | ~$4 |
| Security Hub (30日無料後) | ~$1-3 |
| **合計** | **~$4-7/月** |
