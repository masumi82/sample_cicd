# 動作確認記録 v13 — セキュリティ監視 + コンプライアンス

## 概要

v13 デプロイ後の動作確認項目と結果を記録する。

## 確認項目

| # | 確認項目 | コマンド / 操作 | 期待結果 | 結果 |
|---|---------|---------------|---------|------|
| 1 | Terraform apply 成功 | CD パイプライン | Apply complete! | |
| 2 | CloudTrail Trail 存在 | `aws cloudtrail describe-trails` | `sample-cicd-dev-trail` が存在 | |
| 3 | CloudTrail ログ記録中 | `aws cloudtrail get-trail-status --name sample-cicd-dev-trail` | `IsLogging: true` | |
| 4 | CloudTrail S3 バケット存在 | `aws s3 ls s3://sample-cicd-dev-cloudtrail-logs/` | AWSLogs ディレクトリ存在 | |
| 5 | CloudTrail CloudWatch Logs | CloudWatch コンソール → Log Group `/aws/cloudtrail/sample-cicd-dev` | ログストリーム存在 | |
| 6 | GuardDuty Detector アクティブ | `aws guardduty list-detectors` | Detector ID が返される | |
| 7 | Config Recorder 記録中 | `aws configservice describe-configuration-recorder-status` | `recording: true` | |
| 8 | Config S3 バケット存在 | `aws s3 ls s3://sample-cicd-dev-config/` | AWSLogs ディレクトリ存在 | |
| 9 | Config Rules 評価結果 | `aws configservice describe-compliance-by-config-rule` | 10 ルールの評価結果 | |
| 10 | Security Hub 有効 | `aws securityhub get-enabled-standards` | CIS + FSBP 2 標準 | |
| 11 | SNS トピックポリシー | `aws sns get-topic-attributes` | EventBridge publish 許可あり | |
| 12 | Dashboard Row 9 表示 | CloudWatch コンソール → Dashboard | セキュリティウィジェット 2 個 | |
| 13 | OIDC IAM 権限 | `terraform plan` 成功（権限不足なし） | AccessDeniedException なし | |
| 14 | CI パイプライン成功 | GitHub Actions CI | 全ジョブ PASS | |
| 15 | CD パイプライン成功 | GitHub Actions CD | terraform-apply 成功 | |
| 16 | 既存アプリ正常動作 | `curl https://dev.sample-cicd.click/api/tasks` | 401 (JWT 認証必要) = API 到達確認 | |
| 17 | Web UI 表示 | `curl https://dev.sample-cicd.click/` | SPA HTML 返却 | |
| 18 | ECS サービス稼働 | `aws ecs describe-services` | Running=1, ACTIVE | |

## 備考

- 実施日:
- Config Rules の一部は dev 環境で意図的に NON_COMPLIANT となる（RDS deletion_protection=false, Multi-AZ=false）
- GuardDuty と Security Hub は 30 日間の無料トライアル期間中
- CloudTrail ログは S3 に 15 分程度で出力される（即時ではない）
- Security Hub の findings 生成には数時間かかる場合がある
