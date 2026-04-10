# 動作確認記録 v12 — 災害復旧 + データ保護

## 概要

v12 デプロイ後の動作確認項目と結果を記録する。

## 確認項目

| # | 確認項目 | コマンド / 操作 | 期待結果 | 結果 |
|---|---------|---------------|---------|------|
| 1 | Terraform apply 成功 | `terraform apply -var-file=dev.tfvars` | Apply complete! Resources: ~8 added, ~3 changed | |
| 2 | RDS backup_retention_period | `aws rds describe-db-instances --query 'DBInstances[0].BackupRetentionPeriod'` | 7 | |
| 3 | RDS skip_final_snapshot 無効 | Terraform state で確認 | `skip_final_snapshot = false` | |
| 4 | RDS Backup タグ | `aws rds list-tags-for-resource --resource-name <rds-arn> --query 'TagList'` | `Backup = true` が存在 | |
| 5 | Backup Vault 存在 | `aws backup list-backup-vaults` | `${prefix}-backup-vault` が存在 | |
| 6 | Backup Plan 存在 | `aws backup list-backup-plans` | daily + weekly ルールが存在 | |
| 7 | Backup Vault 通知設定 | `aws backup get-backup-vault-notifications` | SNS Topic ARN が設定されている | |
| 8 | S3 Versioning 有効 | `aws s3api get-bucket-versioning --bucket ${prefix}-attachments` | `Status: Enabled` | |
| 9 | S3 Lifecycle Rules | `aws s3api get-bucket-lifecycle-configuration` | transition-to-ia + noncurrent-lifecycle の 2 ルール | |
| 10 | Read Replica (dev: 無効) | `terraform output rds_read_replica_endpoint` | 空文字列 | |
| 11 | S3 CRR (dev: 無効) | DR バケット不在を確認 | `${prefix}-attachments-dr` が存在しない | |
| 12 | DB_READ_HOST 環境変数 | ECS タスク定義を確認 | `DB_READ_HOST = ""` (dev) | |
| 13 | アプリ正常動作 | `curl ${APP_URL}/api/tasks` | 200 OK | |
| 14 | タスク作成 | `curl -X POST ${APP_URL}/api/tasks ...` | 201 Created | |
| 15 | タスク一覧取得 | `curl ${APP_URL}/api/tasks` | 作成したタスクが含まれる | |
| 16 | Dashboard 表示 | CloudWatch Dashboard を開く | 既存 Row 1-7 正常表示 | |
| 17 | CI パイプライン成功 | GitHub Actions CI | 94 テスト PASS + lint 通過 | |
| 18 | CD パイプライン成功 | GitHub Actions CD | デプロイ完了 | |

## 備考

- 実施日:
- dev 環境では Read Replica / S3 CRR は無効（コスト最小構成）
- AWS Backup の初回バックアップジョブは翌日 JST 3:00 に実行される
- prod 環境での追加確認項目: Read Replica 接続テスト、CRR レプリケーション確認、ReplicaLag ダッシュボード表示
