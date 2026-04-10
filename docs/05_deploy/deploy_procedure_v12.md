# デプロイ手順書 v12 — 災害復旧 + データ保護

## 概要

v12 では以下をデプロイする:
- RDS バックアップ設定強化（retention 7 日、final snapshot 有効）
- AWS Backup（Vault、Plan、Selection、SNS 通知）
- RDS Read Replica（dev: 無効、prod: 有効）
- S3 Versioning 有効化 + Lifecycle Rules
- S3 Cross-Region Replication（dev: 無効、prod: 有効）
- アプリケーション読み書き分離（`get_read_db()`）
- モニタリング拡張（Replica Dashboard + ReplicaLag Alarm）

## 前提条件

- v11 インフラが稼働中であること
- `terraform workspace select dev` で dev 環境が選択済み
- OIDC 認証が正常動作していること

## 手順

### Step 1: Terraform ファイル確認

以下のファイルが追加・変更されていることを確認:

| ファイル | 種別 |
|----------|------|
| `infra/backup.tf` | 新規 |
| `infra/s3_dr.tf` | 新規 |
| `infra/rds.tf` | 変更 |
| `infra/s3.tf` | 変更 |
| `infra/main.tf` | 変更 |
| `infra/variables.tf` | 変更 |
| `infra/dev.tfvars` | 変更 |
| `infra/ecs.tf` | 変更 |
| `infra/monitoring.tf` | 変更 |
| `infra/outputs.tf` | 変更 |

### Step 2: Terraform Plan

```bash
cd infra
terraform workspace select dev
terraform plan -var-file=dev.tfvars
```

**期待される出力** (dev 環境):
```
Plan: ~8 to add, ~3 to change, 0 to destroy
```

主な追加リソース:
- `aws_backup_vault.main`
- `aws_backup_plan.main`
- `aws_backup_selection.rds`
- `aws_backup_vault_notifications.main`
- `aws_iam_role.backup` + policy attachments
- `aws_s3_bucket_lifecycle_configuration.attachments`

主な変更リソース:
- `aws_db_instance.main`（backup_retention=7, skip_final_snapshot=false, Backup tag）
- `aws_s3_bucket_versioning.attachments`（Enabled）
- `aws_ecs_task_definition.app`（DB_READ_HOST 環境変数追加）
- `aws_cloudwatch_dashboard.main`（変更なし — dev ではレプリカ無効）

> **注**: dev 環境では `enable_read_replica = false`, `enable_s3_replication = false` のため、Read Replica / S3 CRR / レプリカダッシュボード / レプリカアラームは作成されない。

### Step 3: Terraform Apply

```bash
terraform apply -var-file=dev.tfvars
```

> **注**: RDS の `backup_retention_period` 変更はオンライン適用（再起動なし）。AWS Backup Vault の作成は即時。S3 Versioning の有効化も即時。

### Step 4: デプロイ結果確認

```bash
# Backup Vault ARN を確認
terraform output backup_vault_arn

# Read Replica エンドポイント（dev では空文字列）
terraform output rds_read_replica_endpoint
```

### Step 5: アプリケーションデプロイ

ECS タスク定義に `DB_READ_HOST` が追加されているため、次回の CD パイプライン実行で反映される。

```bash
# main ブランチへ push → CD パイプライン自動実行
git push origin main
```

### Step 6: 動作確認

#### 6.1 RDS バックアップ設定確認

```bash
# AWS CLI でバックアップ設定を確認
aws rds describe-db-instances \
  --db-instance-identifier sample-cicd-dev \
  --query 'DBInstances[0].{BackupRetentionPeriod:BackupRetentionPeriod,DeletionProtection:DeletionProtection}' \
  --output table
```

期待: `BackupRetentionPeriod: 7`, `DeletionProtection: False` (dev)

#### 6.2 AWS Backup 確認

```bash
# Backup Vault の存在確認
aws backup list-backup-vaults \
  --query "BackupVaultList[?BackupVaultName=='sample-cicd-dev-backup-vault']" \
  --output table

# Backup Plan の存在確認
aws backup list-backup-plans --query 'BackupPlansList[0].BackupPlanName' --output text
```

#### 6.3 S3 Versioning 確認

```bash
# バージョニング状態を確認
aws s3api get-bucket-versioning --bucket sample-cicd-dev-attachments
```

期待: `{"Status": "Enabled"}`

#### 6.4 S3 Lifecycle 確認

```bash
# ライフサイクルルールを確認
aws s3api get-bucket-lifecycle-configuration --bucket sample-cicd-dev-attachments \
  --query 'Rules[*].{ID:ID,Status:Status}' --output table
```

期待: `transition-to-ia` (Enabled) + `noncurrent-lifecycle` (Enabled)

#### 6.5 アプリケーション動作確認

```bash
APP_URL=$(terraform output -raw app_url)

# タスク CRUD が正常動作すること（読み書き分離のフォールバック確認）
curl -s "${APP_URL}/api/tasks" | jq
curl -s -X POST "${APP_URL}/api/tasks" -H "Content-Type: application/json" \
  -d '{"title":"DR Test"}' | jq
```

#### 6.6 CloudWatch ダッシュボード確認

```bash
# ダッシュボード URL
terraform output dashboard_url
```

既存メトリクス（Row 1-7）が正常表示されることを確認。

## prod 環境での追加手順

prod 環境では `enable_read_replica = true`, `enable_s3_replication = true` のため、追加確認が必要:

```bash
# Read Replica エンドポイント
terraform output rds_read_replica_endpoint

# レプリカダッシュボード確認
# → AWS Console で ${prefix}-replica-dashboard を確認

# S3 CRR 確認: ファイルアップロード後に DR バケットへ複製されることを確認
aws s3api head-object --bucket sample-cicd-prod-attachments-dr --key <uploaded-key> --region us-west-2
```

## トラブルシューティング

### RDS backup_retention_period 変更エラー

backup_retention_period の変更は通常即時だが、MultiAZ 構成の場合はメンテナンスウィンドウで適用される場合がある。`pending-modified` 状態になった場合は次のメンテナンスウィンドウを待つか、手動で適用:
```bash
aws rds modify-db-instance --db-instance-identifier sample-cicd-dev --apply-immediately
```

### AWS Backup ジョブが実行されない

- Backup Selection のタグ条件を確認（`Backup = true`）
- RDS インスタンスにタグが付いているか確認
- IAM ロールの権限を確認

### S3 CRR のレプリケーション遅延

- ソースバケットのバージョニングが有効か確認
- IAM レプリケーションロールの権限を確認
- CloudWatch メトリクス `ReplicationLatency` を確認

## コスト影響

| 項目 | dev 月額 | prod 月額 |
|------|---------|----------|
| AWS Backup (RDS 20GB) | ~$1 | ~$2 |
| RDS バックアップストレージ | ~$0.50 | ~$0.50 |
| RDS Read Replica | $0 (無効) | ~$15 |
| S3 CRR | $0 (無効) | ~$1 |
| **合計追加コスト** | **~$2/月** | **~$18/月** |
