# 動作確認記録 v12 — 災害復旧 + データ保護

## 概要

v12 デプロイ後の動作確認項目と結果を記録する。

## 確認項目

| # | 確認項目 | コマンド / 操作 | 期待結果 | 結果 |
|---|---------|---------------|---------|------|
| 1 | Terraform apply 成功 | CD パイプライン (run #24221657910) | Apply complete! | PASS — 25 added, 2 changed (PR #11,#12,#13) |
| 2 | RDS backup_retention_period | `aws rds describe-db-instances` | 7 | PASS — PendingModifiedValues: BackupRetentionPeriod=7 (次回メンテナンスで適用) |
| 3 | RDS skip_final_snapshot 無効 | Terraform state | `skip_final_snapshot = false` | PASS — terraform apply で設定済み |
| 4 | RDS Backup タグ | `aws rds list-tags-for-resource` | `Backup = true` | PASS — タグ確認済み |
| 5 | Backup Vault 存在 | `aws backup list-backup-vaults` | vault が存在 | PASS — `sample-cicd-dev-backup-vault` |
| 6 | Backup Plan 存在 | `aws backup list-backup-plans` | plan が存在 | PASS — `sample-cicd-dev-backup-plan` |
| 7 | Backup Vault 通知設定 | `aws backup get-backup-vault-notifications` | SNS 設定済み | PASS — BACKUP_JOB_FAILED + BACKUP_JOB_COMPLETED → SNS |
| 8 | S3 Versioning 有効 | `aws s3api get-bucket-versioning` | `Status: Enabled` | PASS |
| 9 | S3 Lifecycle Rules | `aws s3api get-bucket-lifecycle-configuration` | 2 ルール | PASS — transition-to-ia + noncurrent-lifecycle |
| 10 | Read Replica (dev: 無効) | ECS タスク定義確認 | 空文字列 | PASS — `DB_READ_HOST = ""` |
| 11 | S3 CRR (dev: 無効) | `enable_s3_replication = false` | DR バケット不在 | PASS — 条件付きリソース未作成 |
| 12 | DB_READ_HOST 環境変数 | `aws ecs describe-task-definition` | `DB_READ_HOST = ""` (dev) | PASS |
| 13 | アプリ正常動作 | `curl https://dev.sample-cicd.click/api/tasks` | 401 (JWT 認証必要) | PASS — 認証エラーは正常動作（API Gateway 経由到達確認） |
| 14 | Web UI 表示 | `curl https://dev.sample-cicd.click/` | SPA HTML 返却 | PASS — React SPA 正常表示 |
| 15 | ECS サービス稼働 | `aws ecs describe-services` | Running=1, ACTIVE | PASS — 1 タスク稼働中 |
| 16 | CI パイプライン成功 | GitHub Actions CI (PR #11,#12,#13) | 94 テスト PASS + lint | PASS — 全 PR で CI 全パス |
| 17 | CD パイプライン成功 | GitHub Actions CD (run #24221657910) | terraform-apply + deploy 成功 | PASS — 全ステップ成功 |
| 18 | Backup ジョブ手動実行 | `aws backup start-backup-job` | COMPLETED | PASS — 約4分で完了 (job-06a17c9c) |
| 19 | リカバリポイント確認 | `aws backup list-recovery-points-by-backup-vault` | vault にポイント存在 | PASS — RDS スナップショット作成済み |
| 20 | CloudWatch Alarm 数 | `aws cloudwatch describe-alarms` | 16件 (dev: replica-lag なし) | PASS — 既存16件。replica-lag は dev では条件付き未作成で正常 |

## 備考

- 実施日: 2026-04-10
- 全 20 項目 PASS
- dev 環境では Read Replica / S3 CRR は無効（コスト最小構成）
- AWS Backup 手動ジョブで正常動作を確認済み。自動スケジュールは毎日 JST 3:00
- prod 環境での追加確認項目: Read Replica 接続テスト、CRR レプリケーション確認、ReplicaLag ダッシュボード表示
- 修正 PR: #12 (backup IAM + S3 lifecycle filter), #13 (backup-storage + KMS 権限)
- Secrets Manager は infra-cleanup 後の state ドリフトにより再作成が必要だった（force-delete → terraform recreate で解決）
- RDS backup_retention_period の変更は pending-modified 状態（次回メンテナンスウィンドウで自動適用）
