# 要件定義書 (v13)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-10 |
| バージョン | 13.0 |
| 前バージョン | [requirements_v12.md](requirements_v12.md) (v12.0) |

## 変更概要

v12（災害復旧 + データ保護）に以下を追加する:

- **CloudTrail**: AWS API コールの監査証跡。管理イベントの記録 + 専用 S3 バケット + CloudWatch Logs 連携
- **GuardDuty**: 脅威検出。不正アクセスや異常な API 呼び出しの自動検出と通知
- **AWS Config**: リソース設定の継続的記録と 10 個のマネージドルールによるコンプライアンス評価
- **Security Hub**: セキュリティ findings の集約。CIS Benchmark + AWS Foundational Security Best Practices 標準
- **EventBridge→SNS 通知**: セキュリティイベントの即時通知（既存 SNS トピックに統合）
- **モニタリング拡張**: セキュリティメトリクスのダッシュボード追加

## 1. プロジェクト概要

### 1.1 目的

v12 までで CI/CD パイプライン、インフラ、データ保護の整備が完了した。しかしセキュリティの「検知・監査」面に以下の致命的な課題がある:

1. **監査証跡の不在**: 誰が・いつ・何をしたかの記録がない。AWS API コールのログが取得されておらず、インシデント発生時の原因調査が不可能
2. **脅威検出手段の不在**: 不正アクセスや異常な動作を検出する仕組みがない。攻撃を受けても気づけない
3. **コンプライアンス評価の不在**: リソースの設定が安全かどうかを継続的に評価する手段がない。S3 のパブリックアクセスや RDS の暗号化設定を人手で確認している
4. **セキュリティ姿勢の可視化なし**: セキュリティ全体のスコアや findings を一元的に把握する手段がない

v12 までで「防御」（WAF, Cognito, Hooks, .claudeignore）は整備した。v13 では「検知」（GuardDuty）と「監査」（CloudTrail, Config, Security Hub）を追加し、**防御 + 検知 + 監査** の 3 層セキュリティを実現する。

### 1.2 学習目標

| # | 学習テーマ | 内容 | デプロイ |
|---|-----------|------|:---:|
| 1 | CloudTrail | 管理イベント証跡の作成、S3 ログ保管、CloudWatch Logs 統合 | |
| 2 | CloudTrail S3 設計 | 専用バケット、バケットポリシー、ライフサイクルルール | |
| 3 | GuardDuty | 脅威検出の有効化、findings の種類と重要度 | |
| 4 | AWS Config | Configuration Recorder, Delivery Channel, マネージドルール | |
| 5 | Config ルール設計 | 既存リソースに対するコンプライアンス評価、COMPLIANT/NON_COMPLIANT の意味 | |
| 6 | Security Hub | セキュリティ標準（CIS, FSBP）の購読、findings の統合 | |
| 7 | EventBridge セキュリティパターン | default bus でのセキュリティイベント→SNS 通知 | |
| 8 | セキュリティ監視ダッシュボード | CloudWatch でのセキュリティメトリクス可視化 | |

### 1.3 スコープ

**スコープ内:**

- CloudTrail
  - 管理イベント証跡（`is_multi_region_trail = true`）
  - 専用 S3 バケット（SSE-S3 暗号化、パブリックアクセスブロック、ライフサイクル）
  - CloudWatch Logs への連携（IAM ロール + ロググループ）
- GuardDuty
  - `enable_guardduty` 変数で条件付き（dev/prod 共に `true`、30 日間無料枠あり）
  - EventBridge ルールで severity >= MEDIUM の findings を SNS 通知
- AWS Config
  - Configuration Recorder（全リソースタイプ記録）
  - Delivery Channel（専用 S3 バケットへスナップショット配信）
  - 10 個のマネージドルール（FR-81 参照）
  - EventBridge ルールで NON_COMPLIANT 変更を SNS 通知
- Security Hub
  - `enable_securityhub` 変数で条件付き（dev/prod 共に `true`、30 日間無料枠あり）
  - CIS AWS Foundations Benchmark 標準購読
  - AWS Foundational Security Best Practices 標準購読
  - EventBridge ルールで HIGH/CRITICAL findings を SNS 通知
  - AWS Config が前提条件（`depends_on` 指定）
- セキュリティイベント通知
  - EventBridge **default** bus（既存カスタムバスではない）
  - 既存 `aws_sns_topic.alarm_notifications` へ統合
  - SNS トピックポリシーに EventBridge からの publish 許可追加
- モニタリング拡張
  - ダッシュボード Row 9: セキュリティメトリクスウィジェット
- OIDC IAM 更新
  - GitHub Actions ロールに `guardduty:*`, `securityhub:*`, `config:*`, `cloudtrail:*` 追加

**スコープ外:**

- CloudTrail データイベント（S3 オブジェクトレベルログ等 — コスト高）
- CloudTrail Insights（異常な API 使用パターン検出 — 追加コスト）
- GuardDuty の保護プラン（S3 Protection, EKS Protection 等 — 追加コスト）
- AWS Config カスタムルール（Lambda ベース — マネージドルールで十分）
- Security Hub カスタムアクション（Lambda 連携 — 通知で十分）
- AWS Inspector（脆弱性スキャン — Trivy + tfsec で対応済み）
- Amazon Detective（セキュリティ調査 — GuardDuty の延長で学習用途では不要）
- マルチアカウント Security Hub 統合（Organizations — 単一アカウント）
- セキュリティイベント処理 Lambda（EventBridge→SNS で十分）
- アプリケーションコード（`app/`）の変更

## 2. 機能要件

### 既存（v12 から継続）

| ID | 概要 | 変更 |
|----|------|------|
| FR-1 | Hello World API (`GET /`) | なし |
| FR-2 | ヘルスチェック (`GET /health`) | なし |
| FR-3 | CI パイプライン | なし |
| FR-4 | CD パイプライン | **更新**（新リソースのデプロイ追加） |
| FR-5〜FR-9 | タスク CRUD API | なし |
| FR-10 | データベース永続化 | なし |
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
| FR-51 | OIDC 認証 | **更新**（IAM 権限追加） |
| FR-52 | Terraform CI/CD | なし |
| FR-53 | Infracost | なし |
| FR-54〜FR-55 | Environments + ワークフロー分割 | なし |
| FR-56〜FR-58 | API Gateway (REST API, Cache, Usage Plans) | なし |
| FR-59〜FR-60 | ElastiCache Redis + Cache-aside | なし |
| FR-61 | CloudFront オリジン変更 | なし |
| FR-62 | モニタリング拡張 (v10) | なし |
| FR-63〜FR-70 | Claude Code Hooks, .claudeignore, チーム設定, スキル | なし |
| FR-71 | RDS バックアップ設定強化 | なし |
| FR-72 | AWS Backup 統合バックアップ | なし |
| FR-73 | RDS Read Replica | なし |
| FR-74 | アプリケーション読み書き分離 | なし |
| FR-75 | S3 Versioning + Lifecycle Rules | なし |
| FR-76 | S3 Cross-Region Replication | なし |
| FR-77 | モニタリング拡張 (v12) | なし |

### 新規

#### FR-78: CloudTrail 管理イベント証跡

| 項目 | 内容 |
|------|------|
| ID | FR-78 |
| 概要 | CloudTrail で AWS API コールの管理イベントを記録する証跡を作成する |
| 新規ファイル | `infra/cloudtrail.tf` |
| Trail | `${local.prefix}-trail`, `is_multi_region_trail = true`, `enable_logging = true` |
| S3 バケット | `${local.prefix}-cloudtrail-logs`, 専用バケット。SSE-S3 暗号化、パブリックアクセスブロック |
| S3 Lifecycle | `cloudtrail_log_retention_days` 日後にログ削除（dev: 90, prod: 365） |
| CloudWatch Logs | CloudTrail → CloudWatch Log Group `/aws/cloudtrail/${local.prefix}` 連携 |
| IAM ロール | CloudTrail が CloudWatch Logs へ書き込むためのサービスロール |
| バケットポリシー | `cloudtrail.amazonaws.com` に `s3:PutObject` + `s3:GetBucketAcl` を許可 |

#### FR-79: GuardDuty 脅威検出

| 項目 | 内容 |
|------|------|
| ID | FR-79 |
| 概要 | GuardDuty を有効化し、脅威検出結果を通知する |
| 新規ファイル | `infra/guardduty.tf` |
| 変数 | `enable_guardduty`（dev: `true`, prod: `true`）。30 日間無料枠あり |
| Detector | `aws_guardduty_detector.main`, `enable = true` |
| EventBridge Rule | **default** バス上で `detail-type: "GuardDuty Finding"`, severity >= MEDIUM をフィルタ |
| SNS Target | 既存 `aws_sns_topic.alarm_notifications` へルーティング |

#### FR-80: AWS Config リソース記録

| 項目 | 内容 |
|------|------|
| ID | FR-80 |
| 概要 | AWS Config でリソース設定変更を継続的に記録する |
| 新規ファイル | `infra/config.tf` |
| Recorder | `aws_config_configuration_recorder.main`, `all_supported = true` |
| Delivery Channel | S3 バケット `${local.prefix}-config` へ設定スナップショット配信 |
| IAM ロール | Config サービスロール（`AWS_ConfigRole` マネージドポリシー + S3 配信ポリシー） |
| S3 バケット | `${local.prefix}-config`, SSE-S3, パブリックアクセスブロック |

#### FR-81: AWS Config ルール（10 ルール）

| 項目 | 内容 |
|------|------|
| ID | FR-81 |
| 概要 | 既存リソースの設定コンプライアンスを 10 個のマネージドルールで評価する |
| ルール一覧 | 下記テーブル参照 |
| 通知 | NON_COMPLIANT 変更時に EventBridge (default bus) → SNS 通知 |

| # | Rule Identifier | チェック対象 | 学習ポイント |
|---|----------------|------------|------------|
| 1 | `S3_BUCKET_PUBLIC_READ_PROHIBITED` | S3 バケット | パブリックアクセス禁止 |
| 2 | `S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED` | S3 バケット | 暗号化の強制 |
| 3 | `S3_BUCKET_VERSIONING_ENABLED` | S3 バケット | バージョニング確認 |
| 4 | `RDS_INSTANCE_DELETION_PROTECTION_ENABLED` | RDS | dev: NON_COMPLIANT（意図的学習） |
| 5 | `RDS_STORAGE_ENCRYPTED` | RDS | ストレージ暗号化 |
| 6 | `RDS_MULTI_AZ_SUPPORT` | RDS | dev: NON_COMPLIANT（意図的学習） |
| 7 | `RESTRICTED_SSH` | セキュリティグループ | SSH ポート制限 |
| 8 | `CLOUD_TRAIL_ENABLED` | CloudTrail | 証跡有効化のメタチェック |
| 9 | `IAM_ROOT_ACCESS_KEY_CHECK` | IAM | ルートアカウントキー不在確認 |
| 10 | `LAMBDA_FUNCTION_PUBLIC_ACCESS_PROHIBITED` | Lambda 関数 | パブリックアクセス禁止 |

#### FR-82: Security Hub セキュリティ統合

| 項目 | 内容 |
|------|------|
| ID | FR-82 |
| 概要 | Security Hub を有効化し、CIS と FSBP の 2 つのセキュリティ標準を購読する |
| 新規ファイル | `infra/securityhub.tf` |
| 変数 | `enable_securityhub`（dev: `true`, prod: `true`）。30 日間無料枠あり |
| 前提条件 | AWS Config が有効であること（`depends_on` 指定） |
| 標準 1 | CIS AWS Foundations Benchmark |
| 標準 2 | AWS Foundational Security Best Practices |
| EventBridge Rule | **default** バス上で Security Hub の HIGH/CRITICAL findings をフィルタ → SNS |

#### FR-83: セキュリティイベント通知（EventBridge → SNS）

| 項目 | 内容 |
|------|------|
| ID | FR-83 |
| 概要 | セキュリティサービスのイベントを EventBridge 経由で既存 SNS トピックに通知する |
| EventBridge バス | **default** バス（既存カスタムバスではない — セキュリティサービスは default bus にイベントを発行する） |
| Rule 1 | GuardDuty findings（severity >= MEDIUM） |
| Rule 2 | Config compliance changes（NON_COMPLIANT） |
| Rule 3 | Security Hub findings（severity HIGH/CRITICAL） |
| Target | 全ルールから `aws_sns_topic.alarm_notifications` へ通知 |
| SNS Policy | EventBridge（`events.amazonaws.com`）からの `sns:Publish` を許可するポリシー追加 |

#### FR-84: モニタリング拡張 (v13)

| 項目 | 内容 |
|------|------|
| ID | FR-84 |
| 概要 | ダッシュボードをセキュリティ監視に対応させる |
| Dashboard Row 9 (y=48) | 2 ウィジェット: (1) CloudTrail イベント数、(2) Config コンプライアンスサマリー |

#### FR-85: OIDC IAM 権限更新

| 項目 | 内容 |
|------|------|
| ID | FR-85 |
| 概要 | GitHub Actions OIDC ロールにセキュリティサービス管理権限を追加する |
| 変更ファイル | `infra/oidc.tf` |
| 追加 Action | `"guardduty:*"`, `"securityhub:*"`, `"config:*"`, `"cloudtrail:*"` |

## 3. 非機能要件

### 既存（v12 から継続）

| ID | 概要 | 変更 |
|----|------|------|
| NFR-1 | 可用性 | なし |
| NFR-2 | セキュリティ | **向上**（監査証跡 + 脅威検出 + コンプライアンス評価） |
| NFR-3 | パフォーマンス | なし |
| NFR-4 | 運用性 | **向上**（セキュリティ姿勢の可視化） |
| NFR-5 | コスト | **変更**（セキュリティサービス追加） |
| NFR-6 | スケーラビリティ | なし |
| NFR-7 | 疎結合性 | なし |
| NFR-8 | コンテンツ配信 | なし |
| NFR-9 | 可観測性 | **更新**（セキュリティダッシュボード） |
| NFR-10 | 認証・認可 | なし |
| NFR-11 | DNS・ドメイン管理 | なし |
| NFR-12 | デプロイ戦略 | なし |
| NFR-13 | CI/CD セキュリティ | なし |
| NFR-14 | API 管理 | なし |
| NFR-15 | キャッシュ耐障害性 | なし |
| NFR-16 | 開発者体験 | なし |
| NFR-17 | 災害復旧 | なし |

### 変更・追加

#### NFR-18: セキュリティ監視・コンプライアンス（新規）

| 項目 | 内容 |
|------|------|
| ID | NFR-18 |
| 監査証跡 | CloudTrail で全リージョンの管理イベントを記録。S3 に 90 日以上保持 |
| 脅威検出 | GuardDuty で不正アクセス・異常動作を自動検出。MEDIUM 以上を即時通知 |
| コンプライアンス | Config で 10 個のルールによるリソース設定の継続的評価。NON_COMPLIANT を即時通知 |
| セキュリティ統合 | Security Hub で CIS + FSBP 標準に基づくセキュリティスコアの一元管理 |
| 通知 | 全セキュリティイベントを既存 SNS トピック（`alarm_notifications`）で一元通知 |
| 3 層セキュリティ | 防御（WAF, Cognito, Hooks）+ 検知（GuardDuty）+ 監査（CloudTrail, Config, Security Hub） |

## 4. 技術スタック

v13 で追加されるサービス:

| カテゴリ | 技術 | 用途 |
|----------|------|------|
| 監査 | CloudTrail | AWS API コールの管理イベント記録 |
| 脅威検出 | GuardDuty | 不正アクセス・異常動作の自動検出 |
| コンプライアンス | AWS Config | リソース設定記録 + マネージドルール評価 |
| セキュリティ統合 | Security Hub | セキュリティ findings の集約 + 標準評価 |
| 通知 | EventBridge (default bus) | セキュリティイベントの SNS ルーティング |

## 5. コスト見積もり

### dev 環境

| 項目 | 月額 |
|------|------|
| 既存インフラ（v12 まで） | 約 $130 |
| CloudTrail（第 1 証跡の管理イベントは無料） | $0 |
| CloudTrail S3 ログストレージ (~100MB/月) | 約 $0.50 |
| CloudTrail CloudWatch Logs | 約 $0.50 |
| AWS Config Recorder + 10 ルール | 約 $2〜3 |
| GuardDuty（30 日間無料、その後） | 約 $4 |
| Security Hub（30 日間無料、その後） | 約 $1〜3 |
| EventBridge ルール | $0 |
| **v13 dev 合計** | **約 $134〜137/月（+$4〜7）** |

> 初月は GuardDuty + Security Hub の 30 日間無料枠により約 $131〜134/月

### prod 環境（追加分）

| 項目 | 追加月額 |
|------|------|
| CloudTrail S3（365 日保持、ログ量増加） | 約 +$1〜2 |
| その他は dev と同等 | 約 +$4〜7 |
| **v13 prod 追加** | **約 +$5〜9/月** |

## 6. 前提条件・制約

### 前提条件

- v12 の全成果物が完成済みであること
- SNS トピック `alarm_notifications` が存在すること
- IAM ロールの作成権限があること（OIDC ロール経由）
- Terraform Remote State が設定済みであること（v8）

### 制約

- CloudTrail の第 1 証跡の管理イベントは無料だが、データイベントは追加料金が発生する
- GuardDuty と Security Hub は 30 日間の無料トライアル後に課金が始まる
- Security Hub は AWS Config が有効であることが前提条件。Config なしでは Security Hub のルール評価が動作しない
- AWS Config Recorder はリージョンごとに 1 つのみ作成可能。既に手動で有効化されている場合は `terraform import` が必要
- GuardDuty Detector もリージョンごとに 1 つのみ。既に有効化されている場合は同上
- セキュリティサービスのイベントは **default** EventBridge バスに発行される。既存のカスタムバス（`${prefix}-bus`）は使用できない
- CloudTrail の S3 バケットポリシーは Trail 作成前に設定が必要
- Config のマネージドルール identifier は UPPER_CASE（例: `S3_BUCKET_PUBLIC_READ_PROHIBITED`）

## 7. 実装方針

### 7.1 セキュリティサービス間の依存関係

```
CloudTrail (独立)
  → S3 バケットポリシー → Trail 作成

Config (独立)
  → IAM ロール → Recorder → Delivery Channel → Recorder Status (開始)
  → 10x Config Rules

Security Hub (Config に依存)
  → depends_on: Config Recorder Status
  → CIS + FSBP Standards

GuardDuty (独立, 条件付き)
  → Detector

EventBridge Rules (各サービスに依存)
  → GuardDuty findings → SNS
  → Config compliance → SNS
  → Security Hub findings → SNS
```

### 7.2 ファイル構成の変更

```
infra/
  cloudtrail.tf            # 新規: CloudTrail Trail + S3 + CloudWatch Logs
  guardduty.tf             # 新規: GuardDuty Detector (条件付き) + EventBridge
  config.tf                # 新規: Config Recorder + 10 Rules + EventBridge
  securityhub.tf           # 新規: Security Hub + CIS/FSBP (条件付き) + EventBridge
  variables.tf             # 変更: v13 変数セクション追加
  dev.tfvars               # 変更: v13 値追加
  prod.tfvars              # 変更: v13 値追加
  oidc.tf                  # 変更: 4 サービス権限追加
  sns.tf                   # 変更: SNS トピックポリシー追加
  monitoring.tf            # 変更: Dashboard Row 9 追加
  outputs.tf               # 変更: 3 出力値追加
```

### 7.3 EventBridge の設計判断

v4 で作成した **カスタム** EventBridge バス（`${prefix}-bus`）はアプリケーションイベント用。セキュリティサービス（GuardDuty, Config, Security Hub）は **default** バスにイベントを発行するため、v13 の EventBridge ルールは `event_bus_name` を指定しない（= default bus を使用）。

これは v4 の既存 EventBridge パターンとは異なる重要な設計判断である。

## 8. 用語集（v13 追加分）

| 用語 | 説明 |
|------|------|
| CloudTrail | AWS API コールの監査証跡サービス。「誰が・いつ・何をしたか」を記録 |
| 管理イベント | AWS リソースの作成・変更・削除に関する API コール。CloudTrail の基本記録対象 |
| データイベント | S3 オブジェクトや Lambda 関数の呼び出しなど、リソース内のデータ操作イベント |
| GuardDuty | AWS の脅威検出サービス。CloudTrail, VPC Flow Logs, DNS ログを分析して不正を検出 |
| GuardDuty Finding | GuardDuty が検出した脅威情報。severity（LOW/MEDIUM/HIGH/CRITICAL）で分類 |
| AWS Config | リソース設定の継続的記録・評価サービス |
| Configuration Recorder | AWS Config がリソースの設定変更を記録するコンポーネント |
| Config Rule | リソース設定がコンプライアンスに準拠しているかを評価するルール |
| マネージドルール | AWS が事前定義した Config ルール。カスタムロジック不要で利用可能 |
| COMPLIANT / NON_COMPLIANT | Config ルール評価の結果。準拠 / 非準拠 |
| Security Hub | AWS のセキュリティ findings 集約サービス。複数サービスの結果を一元管理 |
| CIS Benchmark | Center for Internet Security が定めるセキュリティベンチマーク。業界標準 |
| FSBP | AWS Foundational Security Best Practices。AWS 推奨のセキュリティ基準 |
| Security Standard | Security Hub が評価するセキュリティ基準のセット |
| default bus | EventBridge のデフォルトイベントバス。AWS サービスのイベントはここに発行される |
| 3 層セキュリティ | 防御（Prevention）+ 検知（Detection）+ 監査（Audit）の多層防御アプローチ |
