# 要件定義書 (v12)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-10 |
| バージョン | 12.0 |
| 前バージョン | [requirements_v11.md](requirements_v11.md) (v11.0) |

## 変更概要

v11（組織レベル Claude Code ベストプラクティス）に以下を追加する:

- **AWS Backup**: RDS の日次・週次バックアップを統合管理。Vault, Plan, Selection による自動バックアップ
- **RDS Read Replica**: 読み取りスケーリング。アプリケーション層での読み書き分離パターン（Graceful degradation）
- **S3 Cross-Region Replication (CRR)**: 添付ファイルバケットのクロスリージョン DR
- **S3 Versioning + Lifecycle Rules**: オブジェクトバージョン管理、ストレージクラス自動移行によるコスト最適化
- **モニタリング拡張**: レプリカラグ・バックアップジョブのダッシュボード追加とアラーム

## 1. プロジェクト概要

### 1.1 目的

v11 までで CI/CD パイプライン、インフラ、チーム運用の整備が完了した。しかしデータ保護と災害復旧に以下の致命的な課題がある:

1. **バックアップ戦略の不在**: RDS の `backup_retention_period = 0`、`skip_final_snapshot = true` で、障害時にデータ復旧が不可能。本番環境では致命的
2. **読み取りスケーリング手段の不在**: 全ての DB クエリがプライマリインスタンスに集中。Redis キャッシュ（v10）でカバーできないクエリはプライマリの負荷に直結
3. **S3 データの冗長性不足**: 添付ファイルバケットのバージョニングが無効（`s3_versioning_enabled = false`）。誤削除時の復旧手段がない
4. **クロスリージョン DR なし**: 全リソースが `ap-northeast-1` 単一リージョン。リージョン障害時のデータ復旧計画がない

v12 ではこれらを解決し、データ保護と災害復旧のパターンを学習する。

### 1.2 学習目標

| # | 学習テーマ | 内容 | デプロイ |
|---|-----------|------|:---:|
| 1 | AWS Backup | Backup Vault, Plan, Selection の作成、スケジュール設定、SNS 通知連携 | |
| 2 | RDS バックアップ設定 | retention period, final snapshot, point-in-time recovery の概念 | |
| 3 | RDS Read Replica | レプリカ作成、レプリカラグ監視、プライマリとの関係 | |
| 4 | 読み書き分離パターン | アプリケーション層での DB セッション分離、Graceful degradation | |
| 5 | S3 Versioning | バケットバージョニング、バージョンID、誤削除からの復旧 | |
| 6 | S3 Lifecycle Rules | ストレージクラス移行（Standard → Standard-IA → Glacier）、コスト最適化 | |
| 7 | S3 Cross-Region Replication | レプリケーション設定、IAM ロール、DR リージョンバケット | |
| 8 | CloudWatch 監視拡張 | レプリカラグメトリクス、バックアップジョブ監視、アラーム設計 | |

### 1.3 スコープ

**スコープ内:**

- RDS バックアップ設定の修正
  - `backup_retention_period` を `0` → `7` に変更
  - `skip_final_snapshot` を `true` → `false` に変更（`final_snapshot_identifier` 設定）
  - `deletion_protection` を変数化（dev: `false`, prod: `true`）
- AWS Backup
  - Backup Vault の作成
  - Backup Plan: RDS 日次バックアップ（保持 7 日）+ 週次バックアップ（保持 30 日）
  - Backup Selection: タグベースで RDS インスタンスを選択
  - 既存 SNS トピックへのバックアップ通知
  - Backup サービス用 IAM ロール
- RDS Read Replica
  - `enable_read_replica` 変数で条件付き作成（dev: `false`, prod: `true`）
  - レプリカ用セキュリティグループ（ECS タスクからの PostgreSQL ポート許可）
  - レプリカエンドポイントの ECS 環境変数注入（`DATABASE_READ_URL`）
- アプリケーション読み書き分離
  - `app/database.py`: `DATABASE_READ_URL` 環境変数対応、読み取り専用セッション
  - `app/routers/tasks.py`: `list_tasks`, `get_task` を読み取りセッションへルーティング
  - Graceful degradation: `DATABASE_READ_URL` 未設定時はプライマリにフォールバック
- S3 Versioning 有効化
  - 添付ファイルバケットの `s3_versioning_enabled` デフォルトを `true` に変更
- S3 Lifecycle Rules
  - 現行バージョン: 90 日後 → Standard-IA
  - 旧バージョン: 30 日後 → Glacier、90 日後 → 完全削除
  - 変数で日数をカスタマイズ可能
- S3 Cross-Region Replication
  - DR リージョン（`us-west-2`）の S3 バケット（レプリケーション先）
  - レプリケーション設定（添付ファイルバケット → DR バケット）
  - レプリケーション用 IAM ロール
  - `enable_s3_replication` 変数で条件付き（dev: `false`, prod: `true`）
- モニタリング拡張
  - ダッシュボードに Row 8: RDS Replica Lag + AWS Backup ウィジェット追加
  - アラーム: ReplicaLag 高 + Backup ジョブ失敗
- テスト
  - 読み書き分離のユニットテスト（`test_db_routing.py`）

**スコープ外:**

- RDS Read Replica の自動フェイルオーバー（Multi-AZ と役割が異なる、読み取り専用のまま）
- RDS Aurora への移行（学習コストとコストが大きすぎる）
- S3 Object Lock（コンプライアンス要件なし）
- S3 Glacier Deep Archive（学習用途では不要）
- DynamoDB バックアップ（Terraform state lock テーブルのみ、アプリデータなし）
- クロスリージョン RDS Read Replica（コストが高い、同リージョンで十分）

## 2. 機能要件

### 既存（v11 から継続）

| ID | 概要 | 変更 |
|----|------|------|
| FR-1 | Hello World API (`GET /`) | なし |
| FR-2 | ヘルスチェック (`GET /health`) | なし |
| FR-3 | CI パイプライン | なし |
| FR-4 | CD パイプライン | **更新**（新リソースのデプロイ追加） |
| FR-5〜FR-9 | タスク CRUD API | **更新**（読み書き分離） |
| FR-10 | データベース永続化 | **更新**（バックアップ + Read Replica） |
| FR-11 | ECS Auto Scaling | なし |
| FR-12〜FR-14 | イベント駆動処理 | なし |
| FR-15〜FR-18 | 添付ファイル CRUD API | なし |
| FR-19 | マルチ環境管理 | なし |
| FR-20〜FR-24 | Observability | **更新**（ダッシュボード拡張） |
| FR-25〜FR-29 | Web UI | なし |
| FR-30 | CORS ミドルウェア | なし |
| FR-31 | フロントエンド CI/CD | なし |
| FR-32〜FR-38 | Cognito 認証 | なし |
| FR-39〜FR-40 | WAF | なし |
| FR-41〜FR-47 | HTTPS + カスタムドメイン + Remote State | なし |
| FR-48 | CodeDeploy B/G デプロイ | なし |
| FR-49〜FR-50 | セキュリティスキャン (Trivy, tfsec) | なし |
| FR-51 | OIDC 認証 | なし |
| FR-52 | Terraform CI/CD | なし |
| FR-53 | Infracost | なし |
| FR-54〜FR-55 | Environments + ワークフロー分割 | なし |
| FR-56〜FR-58 | API Gateway (REST API, Cache, Usage Plans) | なし |
| FR-59〜FR-60 | ElastiCache Redis + Cache-aside | なし |
| FR-61 | CloudFront オリジン変更 | なし |
| FR-62 | モニタリング拡張 (v10) | なし |
| FR-63〜FR-70 | Claude Code Hooks, .claudeignore, チーム設定, スキル | なし |

### 新規

#### FR-71: RDS バックアップ設定強化

| 項目 | 内容 |
|------|------|
| ID | FR-71 |
| 概要 | RDS のバックアップ設定を本番レベルに強化する |
| 変更対象 | `infra/rds.tf` — `aws_db_instance.main` |
| backup_retention_period | `0` → `7`（7 日間の自動バックアップ保持） |
| skip_final_snapshot | `true` → `false`（DB 削除時にスナップショット取得） |
| final_snapshot_identifier | `${local.prefix}-final-snapshot` |
| deletion_protection | 変数 `db_deletion_protection` で制御（dev: `false`, prod: `true`） |
| 変数追加 | `infra/variables.tf` に `db_backup_retention_period`, `db_deletion_protection` を追加 |

#### FR-72: AWS Backup 統合バックアップ

| 項目 | 内容 |
|------|------|
| ID | FR-72 |
| 概要 | AWS Backup で RDS の日次・週次バックアップを統合管理する |
| 新規ファイル | `infra/backup.tf` |
| Backup Vault | `${local.prefix}-backup-vault`。デフォルト暗号化（AWS マネージドキー） |
| Backup Plan (日次) | 毎日 UTC 18:00（JST 3:00）実行、保持 7 日、CRON: `cron(0 18 * * ? *)` |
| Backup Plan (週次) | 毎週日曜 UTC 18:00 実行、保持 30 日、CRON: `cron(0 18 ? * 1 *)` |
| Backup Selection | タグ `Backup = true` でリソースを選択。RDS インスタンスにタグ追加 |
| SNS 通知 | Backup Vault の通知設定で既存 `aws_sns_topic.alarm_notifications` へ通知（BACKUP_JOB_COMPLETED, BACKUP_JOB_FAILED） |
| IAM ロール | AWS Backup サービスロール（`AWSBackupServiceRolePolicyForBackup` + `AWSBackupServiceRolePolicyForRestores` マネージドポリシー） |

#### FR-73: RDS Read Replica

| 項目 | 内容 |
|------|------|
| ID | FR-73 |
| 概要 | RDS Read Replica を作成し、読み取りクエリの負荷分散を実現する |
| 変数 | `enable_read_replica`（dev: `false`, prod: `true`）で条件付き作成 |
| リソース | `aws_db_instance.read_replica`（`count` で制御） |
| 設定 | `replicate_source_db = aws_db_instance.main.identifier`、`instance_class = var.db_instance_class` |
| SG | 既存 `aws_security_group.rds` を共有（ECS タスクからの PostgreSQL ポート許可） |
| ECS 環境変数 | `DATABASE_READ_URL` をタスク定義に追加（レプリカエンドポイント。レプリカ無効時は空文字列） |
| 監視 | ダッシュボードに ReplicaLag メトリクス追加。ReplicaLag > 30 秒でアラーム |

#### FR-74: アプリケーション読み書き分離

| 項目 | 内容 |
|------|------|
| ID | FR-74 |
| 概要 | アプリケーション層で DB の読み書きセッションを分離する |
| 変更: `app/database.py` | `DATABASE_READ_URL` 環境変数を参照。設定時は読み取り専用エンジン + セッションを作成。未設定時はプライマリにフォールバック（Graceful degradation） |
| 新規関数 | `get_read_db()` — 読み取り専用セッションを yield する FastAPI 依存関数 |
| 変更: `app/routers/tasks.py` | `list_tasks()`, `get_task()` で `get_read_db()` を使用。`create_task()`, `update_task()`, `delete_task()` は既存 `get_db()` のまま |
| 設計原則 | 読み取り系は Read Replica、書き込み系はプライマリ。キャッシュヒット時は DB アクセスなし（既存 Redis キャッシュと共存） |

#### FR-75: S3 Versioning + Lifecycle Rules

| 項目 | 内容 |
|------|------|
| ID | FR-75 |
| 概要 | S3 添付ファイルバケットのバージョニング有効化とライフサイクルルール設定 |
| Versioning | `s3_versioning_enabled` のデフォルトを `false` → `true` に変更 |
| Lifecycle: 現行バージョン | 90 日後 → `STANDARD_IA` に移行 |
| Lifecycle: 旧バージョン | 30 日後 → `GLACIER` に移行、90 日後 → 完全削除 |
| 変数 | `s3_lifecycle_ia_days` (default: 90), `s3_lifecycle_glacier_days` (default: 30), `s3_lifecycle_expire_days` (default: 90) |
| 新規リソース | `aws_s3_bucket_lifecycle_configuration.attachments` |

#### FR-76: S3 Cross-Region Replication

| 項目 | 内容 |
|------|------|
| ID | FR-76 |
| 概要 | 添付ファイルバケットを DR リージョンにクロスリージョンレプリケーションする |
| 変数 | `enable_s3_replication` (dev: `false`, prod: `true`), `dr_region` (default: `us-west-2`) |
| DR バケット | DR リージョンに `${local.prefix}-attachments-dr` バケットを作成。SSE-S3 暗号化、パブリックアクセスブロック |
| provider | `provider "aws" { alias = "dr" region = var.dr_region }` を追加 |
| レプリケーション | `aws_s3_bucket_replication_configuration` で添付バケット → DR バケットへのレプリケーション |
| IAM | レプリケーション用 IAM ロール + ポリシー（ソースの GetObject + GetReplication + 宛先の PutObject） |
| 前提条件 | ソースバケットのバージョニングが有効であること（FR-75 で対応） |

#### FR-77: モニタリング拡張 (v12)

| 項目 | 内容 |
|------|------|
| ID | FR-77 |
| 概要 | ダッシュボードとアラームを V12 の新リソースに対応させる |
| Dashboard Row 8 | RDS Replica Lag + AWS Backup Job Count（条件付き: Read Replica 有効時のみ） |
| Alarm: ReplicaLag | `ReplicaLag > 30` 秒で 2 期間連続 → アラーム |
| Alarm: Backup 失敗 | AWS Backup ジョブ失敗イベントを SNS 通知（Vault 通知で対応） |
| 変数 | `alarm_replica_lag_threshold` (default: 30) |

## 3. 非機能要件

### 既存（v11 から継続）

| ID | 概要 | 変更 |
|----|------|------|
| NFR-1 | 可用性 | **向上**（バックアップ + Read Replica） |
| NFR-2 | セキュリティ | なし |
| NFR-3 | パフォーマンス | **向上**（読み書き分離で読み取り負荷分散） |
| NFR-4 | 運用性 | **向上**（AWS Backup による自動バックアップ管理） |
| NFR-5 | コスト | **変更**（Backup ストレージ + Lifecycle 最適化） |
| NFR-6 | スケーラビリティ | **向上**（Read Replica による読み取りスケーリング） |
| NFR-7 | 疎結合性 | なし |
| NFR-8 | コンテンツ配信 | なし |
| NFR-9 | 可観測性 | **更新**（レプリカ・バックアップ監視） |
| NFR-10 | 認証・認可 | なし |
| NFR-11 | DNS・ドメイン管理 | なし |
| NFR-12 | デプロイ戦略 | なし |
| NFR-13 | CI/CD セキュリティ | なし |
| NFR-14 | API 管理 | なし |
| NFR-15 | キャッシュ耐障害性 | なし |
| NFR-16 | 開発者体験 | なし |

### 変更・追加

#### NFR-1: 可用性（更新）

| 項目 | 内容 |
|------|------|
| ID | NFR-1 |
| RDS バックアップ | 自動バックアップ保持 7 日。ポイントインタイムリカバリ対応 |
| AWS Backup | 日次 + 週次バックアップの二層管理。30 日間の長期保持 |
| RPO 目標 | 24 時間以内（日次バックアップ + ポイントインタイムリカバリで 5 分以内も可能） |
| S3 冗長性 | バージョニング有効化 + クロスリージョンレプリケーション |

#### NFR-17: 災害復旧（新規）

| 項目 | 内容 |
|------|------|
| ID | NFR-17 |
| RDS | 自動バックアップからのリストア手順を文書化 |
| S3 | CRR により DR リージョン（us-west-2）にデータ複製 |
| RTO 目標 | RDS: 30 分以内（スナップショットからリストア）、S3: 即時（DR バケット切替） |
| 制約 | フルリージョンフェイルオーバー（Route 53 + マルチリージョン ECS）はスコープ外 |

## 4. 技術スタック

v12 で追加されるサービス:

| カテゴリ | 技術 | 用途 |
|----------|------|------|
| バックアップ | AWS Backup | RDS の統合バックアップ管理 |
| DB スケーリング | RDS Read Replica | 読み取り負荷分散 |
| ストレージ | S3 Versioning | オブジェクトバージョン管理、誤削除対策 |
| ストレージ | S3 Lifecycle | ストレージクラス自動移行、コスト最適化 |
| DR | S3 Cross-Region Replication | クロスリージョン DR |

## 5. コスト見積もり

### dev 環境（最小構成）

| 項目 | 月額 |
|------|------|
| 既存インフラ（v11 まで） | 約 $126〜128 |
| AWS Backup (RDS 20GB, 日次 7 日保持) | 約 $1.00 |
| RDS バックアップストレージ (7 日保持) | 約 $0.50 |
| RDS Read Replica | **$0**（`enable_read_replica = false`） |
| S3 Versioning 追加ストレージ | 微増 |
| S3 Lifecycle (IA/Glacier 移行) | 微減 |
| S3 Cross-Region Replication | **$0**（`enable_s3_replication = false`） |
| **v12 dev 合計** | **約 $128〜130/月（+$2 程度）** |

### prod 環境（フル構成）

| 項目 | 追加月額 |
|------|------|
| AWS Backup (日次 + 週次) | 約 $2.00 |
| RDS Read Replica (db.t3.micro) | 約 $15 |
| S3 CRR（転送 + DR ストレージ） | 約 $1.00 |
| **v12 prod 追加** | **約 +$18/月** |

## 6. 前提条件・制約

### 前提条件

- v11 の全成果物が完成済みであること
- RDS PostgreSQL インスタンスが稼働中であること
- S3 添付ファイルバケットが存在すること
- Terraform Remote State が設定済みであること（v8）

### 制約

- RDS Read Replica はプライマリと同じ AZ に配置される（クロス AZ も可能だが、コスト最適化のためデフォルトは同一リージョン内自動配置）
- Read Replica は読み取り専用。レプリカへの書き込みはエラーになる
- S3 CRR はバージョニング有効が前提条件（CRR 設定前にバージョニングを有効化する必要がある）
- S3 CRR はリージョンの異なるバケット間でのみ動作（同一リージョンは SRR だが今回はスコープ外）
- AWS Backup の Vault は削除時にリカバリポイントが空である必要がある
- `backup_retention_period` 変更は RDS の再起動を伴わない（オンラインで変更可能）
- `skip_final_snapshot = false` への変更は `final_snapshot_identifier` の同時指定が必要
- dev 環境では Read Replica と S3 CRR を無効化してコストを最小限に抑える

## 7. 実装方針

### 7.1 Graceful degradation パターンの継続

v4（SQS/EventBridge）、v7（Cognito）、v10（Redis）と同様、`DATABASE_READ_URL` が未設定の場合は読み取りもプライマリ DB にフォールバックする。これにより:

- ローカル開発時（SQLite 使用時）に Read Replica 不要
- dev 環境で `enable_read_replica = false` でも動作

### 7.2 変数によるコスト制御

| 変数 | dev | prod |
|------|-----|------|
| `enable_read_replica` | `false` | `true` |
| `enable_s3_replication` | `false` | `true` |
| `db_deletion_protection` | `false` | `true` |
| `db_backup_retention_period` | `7` | `7` |
| `s3_versioning_enabled` | `true` | `true` |

### 7.3 ファイル構成の変更

```
infra/
  rds.tf                # 変更: backup 設定 + Read Replica
  s3.tf                 # 変更: Versioning default + Lifecycle
  backup.tf             # 新規: AWS Backup (Vault, Plan, Selection)
  s3_dr.tf              # 新規: DR リージョン S3 + CRR
  monitoring.tf         # 変更: Row 8 + アラーム追加
  security_groups.tf    # 変更なし（既存 RDS SG をレプリカでも共有）
  variables.tf          # 変更: 新変数追加
  ecs.tf                # 変更: DATABASE_READ_URL 環境変数追加
  iam.tf                # 変更: Backup + Replication IAM ロール
app/
  database.py           # 変更: 読み取り専用エンジン + get_read_db()
  routers/tasks.py      # 変更: 読み取り系を get_read_db() に変更
tests/
  test_db_routing.py    # 新規: 読み書き分離テスト
  conftest.py           # 変更: read DB フィクスチャ追加
```

## 8. 用語集（v12 追加分）

| 用語 | 説明 |
|------|------|
| AWS Backup | AWS の統合バックアップサービス。複数サービス（RDS, S3, EFS 等）のバックアップを一元管理 |
| Backup Vault | バックアップデータ（リカバリポイント）の保管庫。暗号化キーを指定可能 |
| Backup Plan | バックアップのスケジュールと保持ポリシーを定義するルールセット |
| Backup Selection | どのリソースをバックアップ対象にするかをタグまたは ARN で指定する設定 |
| Read Replica | プライマリ DB の非同期レプリカ。読み取り専用クエリを処理し、プライマリの負荷を軽減 |
| ReplicaLag | プライマリとレプリカ間のデータ同期遅延。秒単位で測定される |
| 読み書き分離 | 読み取りクエリを Read Replica、書き込みクエリをプライマリに振り分けるアプリケーション設計パターン |
| RPO | Recovery Point Objective。障害時に許容されるデータ損失の最大時間 |
| RTO | Recovery Time Objective。障害発生からサービス復旧までの目標時間 |
| S3 Versioning | S3 オブジェクトの全バージョンを保持する機能。誤削除や上書きからの復旧が可能 |
| S3 Lifecycle | オブジェクトのストレージクラスを経過日数に応じて自動移行するルール |
| Standard-IA | S3 Infrequent Access。アクセス頻度の低いデータ向けの低コストストレージクラス |
| Glacier | 長期アーカイブ向けの最低コストストレージクラス。取り出しに時間がかかる |
| Cross-Region Replication (CRR) | S3 バケット間でオブジェクトを別リージョンに自動複製する機能。DR 対策 |
| Graceful degradation | オプション機能の依存先が利用不可の場合、エラーにせず機能をスキップする設計パターン |
| Point-in-Time Recovery | RDS の自動バックアップから任意の時点（秒単位）のデータにリストアする機能 |
