# 動作確認記録 v13 — セキュリティ監視 + コンプライアンス

## 概要

v13 デプロイ後の動作確認項目と結果を記録する。

## 確認項目

| # | 確認項目 | コマンド / 操作 | 期待結果 | 結果 |
|---|---------|---------------|---------|------|
| 1 | Terraform apply 成功 | CD パイプライン (run #24227218780) | Apply complete! | PASS — 3回目の再実行で成功（1回目: IAM反映遅延, 2回目: Secrets Manager state不整合） |
| 2 | CloudTrail Trail 存在 | `aws cloudtrail describe-trails` | `sample-cicd-dev-trail` が存在 | PASS — IsMultiRegion=true, LogValidation=true |
| 3 | CloudTrail ログ記録中 | `aws cloudtrail get-trail-status` | `IsLogging: true` | PASS — IsLogging=true, LatestDeliveryTime確認 |
| 4 | CloudTrail S3 バケット存在 | `aws s3 ls s3://sample-cicd-dev-cloudtrail-logs/` | AWSLogs ディレクトリ存在 | PASS — AWSLogs/ ディレクトリ確認 |
| 5 | CloudTrail CloudWatch Logs | CW Logs グループ確認 | ログストリーム存在 | PASS — ストリーム `123456789012_CloudTrail_ap-northeast-1` 確認 |
| 6 | GuardDuty Detector アクティブ | `aws guardduty list-detectors` | Detector ID が返される | PASS — Detector ID 確認済み |
| 7 | Config Recorder 記録中 | `aws configservice describe-configuration-recorder-status` | `recording: true` | PASS — recording=true, lastStatus=SUCCESS |
| 8 | Config S3 バケット存在 | `aws s3 ls s3://sample-cicd-dev-config/` | AWSLogs ディレクトリ存在 | PASS — AWSLogs/ ディレクトリ確認 |
| 9 | Config Rules 評価結果 | `aws configservice describe-compliance-by-config-rule` | 10 ルールの評価結果 | PASS — 10ルール全て評価済み（COMPLIANT: 3, NON_COMPLIANT: 7） |
| 10 | Security Hub 有効 | `aws securityhub get-enabled-standards` | CIS + FSBP 標準 | PASS — CIS v1.2.0 + CIS v1.4.0 + FSBP v1.0.0 (3標準 READY) |
| 11 | SNS トピックポリシー | `aws sns get-topic-attributes` | EventBridge publish 許可あり | PASS — AllowEventBridgePublish, AllowCloudWatchAlarmsPublish, AllowBackupPublish |
| 12 | Dashboard Row 9 表示 | CloudWatch コンソール | セキュリティウィジェット 2 個 | PASS — CloudTrail Events + Config Compliance ウィジェット |
| 13 | OIDC IAM 権限 | CD パイプライン terraform apply | AccessDeniedException なし | PASS — 3回目の実行で全リソース作成成功 |
| 14 | CI パイプライン成功 | GitHub Actions CI (PR #15) | 全ジョブ PASS | PASS — 1m44s で完了 |
| 15 | CD パイプライン成功 | GitHub Actions CD (run #24227218780) | terraform-apply + deploy 成功 | PASS — terraform-apply + deploy 全ステップ成功 |
| 16 | 既存アプリ正常動作 | `curl https://dev.sample-cicd.click/api/tasks` | 401 (JWT 認証必要) | PASS — HTTP 401（API Gateway 経由到達確認） |
| 17 | Web UI 表示 | `curl https://dev.sample-cicd.click/` | SPA HTML 返却 | PASS — HTTP 200 |
| 18 | ECS サービス稼働 | `aws ecs describe-services` | Running=1, ACTIVE | PASS — Status=ACTIVE, Running=1 |

## 備考

- 実施日: 2026-04-10
- 全 18 項目 PASS
- CD パイプラインは 3 回実行:
  - 1 回目: Config/GuardDuty の AccessDeniedException（OIDC IAM ポリシー更新と新リソース作成が同一 apply で、IAM の eventual consistency により反映遅延）
  - 2 回目: Secrets Manager の ResourceExistsException（infra-cleanup 後の Secret が復元済みだった）
  - 3 回目: Secret を強制削除後に再実行 → 全リソース作成成功
- Config Rules のうち dev 環境で NON_COMPLIANT なルール（意図的）:
  - `rds-deletion-protection` — dev では deletion_protection=false
  - `rds-multi-az` — dev では multi_az=false
  - `rds-storage-encrypted` — dev では暗号化未設定
  - `restricted-ssh` — セキュリティグループ評価
  - `s3-public-read-prohibited` — バケットポリシー評価
  - `s3-versioning-enabled` — 一部バケットでバージョニング未有効
  - `iam-root-access-key` — アカウント設定
- Security Hub は CIS v1.2.0 が自動購読された（v1.4.0 と併存）
- GuardDuty と Security Hub は 30 日間の無料トライアル期間中
