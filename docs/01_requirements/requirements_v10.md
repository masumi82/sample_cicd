# 要件定義書 (v10)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-08 |
| バージョン | 10.0 |
| 前バージョン | [requirements_v9.md](requirements_v9.md) (v9.0) |

## 変更概要

v9（CI/CD 完全自動化 + セキュリティスキャン）に以下を追加する:

- **API Gateway (REST API)**: ALB の前段に API Gateway を配置し、API 管理レイヤーを追加。スロットリング、Usage Plans、API キー、レスポンスキャッシュを提供
- **ElastiCache Redis**: アプリケーションレベルの DB クエリキャッシュを追加。Cache-aside パターンで読み取りパフォーマンスを向上
- **レート制限の多層化**: WAF（L7）+ API Gateway（API 管理）+ Usage Plans（API キー単位）の 3 層レート制限

## 1. プロジェクト概要

### 1.1 目的

v9 までで CI/CD パイプラインが完成し、インフラ・デプロイの自動化が達成された。しかし API 管理とパフォーマンス面に以下の課題がある:

1. **API 管理レイヤーの不在**: ALB が直接 API トラフィックを処理しており、スロットリング・API キー管理・使用量制御ができない。外部連携時の API アクセス制御に課題
2. **キャッシュレイヤーの不在**: すべての GET リクエストが RDS に到達し、読み取り負荷が高い。頻繁にアクセスされるタスク一覧や個別タスクのキャッシュが未実装
3. **レート制限が単一層**: WAF の IP ベースレート制限のみ。API キー単位やエンドポイント単位のきめ細かい制御ができない

v10 ではこれらを解決し、API 管理とパフォーマンス最適化のパターンを学習する。

### 1.2 学習目標

| # | 学習テーマ | 内容 | デプロイ |
|---|-----------|------|:---:|
| 1 | API Gateway REST API | REST API の作成、リソース・メソッド定義、HTTP プロキシ統合 | ✅ |
| 2 | API Gateway キャッシュ | ステージレベルキャッシュ、TTL 設定、メソッド別キャッシュ有効/無効 | ✅ |
| 3 | Usage Plans + API Keys | API キーの発行、使用量プラン（レート制限 + クォータ）の設定 | ✅ |
| 4 | API Gateway スロットリング | アカウントレベル・ステージレベル・メソッドレベルのスロットリング | ✅ |
| 5 | ElastiCache Redis | Redis クラスタ作成、VPC 内配置、セキュリティグループ設計 | ✅ |
| 6 | Cache-aside パターン | Redis による DB クエリキャッシュ、TTL 管理、書き込み時の無効化 | ✅ |
| 7 | Graceful degradation | Redis 障害時のフォールバック（DB 直接アクセス）、エラーハンドリング | ✅ |
| 8 | CloudFront + API Gateway 統合 | CloudFront のオリジンとして API Gateway を設定、API キーの自動注入 | ✅ |

### 1.3 スコープ

**スコープ内:**

- API Gateway REST API (REGIONAL エンドポイント)
  - `/tasks` および `/tasks/{proxy+}` リソース定義
  - ANY メソッド + HTTP プロキシ統合（ALB 向け）
  - ステージキャッシュの有効化（GET メソッドのみ）
  - Usage Plan + API キーの作成
  - ステージレベル・メソッドレベルのスロットリング設定
  - CloudWatch アクセスログの有効化
  - IAM ロール（CloudWatch ログ出力用）
- ElastiCache Redis
  - 単一ノード Redis クラスタ（dev: `cache.t3.micro`）
  - プライベートサブネットへの配置（RDS と同じサブネットグループ）
  - セキュリティグループ（ECS タスクからの 6379 ポートのみ許可）
- アプリケーションレベルキャッシュ
  - `app/services/cache.py` — Redis キャッシュサービス（Graceful degradation）
  - `app/routers/tasks.py` — Cache-aside パターン統合
  - `redis` ライブラリの追加
- CloudFront 設定変更
  - `/tasks*` のオリジンを ALB → API Gateway に変更
  - `x-api-key` ヘッダーを CloudFront custom_header で API Gateway に注入
- モニタリング拡張
  - CloudWatch Dashboard に API Gateway + ElastiCache メトリクス追加
  - API Gateway 5xx エラー、レイテンシ、Redis CPU、Evictions のアラーム追加
- テスト
  - キャッシュ関連テスト（hit/miss、invalidation、graceful degradation）

**スコープ外:**

- API Gateway カスタムドメイン（CloudFront 経由でアクセスするため不要）
- API Gateway Lambda オーソライザー（Cognito JWT 認証は ECS 側で処理済み）
- Redis Cluster モード（単一ノードで十分）
- Redis レプリケーション（dev 環境のため不要）
- Redis AUTH / TLS（VPC 内通信のため学習用には不要）
- API Gateway WebSocket API
- VPC Link（HTTP プロキシ統合で ALB に接続するため不要）
- アプリケーションレベルのレート制限ミドルウェア（API Gateway のスロットリングで十分）
- セッションキャッシュ（Cognito JWT はステートレスのため不要）

## 2. 機能要件

### 既存（v9 から継続）

| ID | 概要 | 変更 |
|----|------|------|
| FR-1 | Hello World API (`GET /`) | なし |
| FR-2 | ヘルスチェック (`GET /health`) | なし |
| FR-3 | CI パイプライン | 軽微変更（テスト依存追加） |
| FR-4 | CD パイプライン | なし |
| FR-5〜FR-9 | タスク CRUD API | **変更**（Redis キャッシュ統合） |
| FR-10 | データベース永続化 | なし |
| FR-11 | ECS Auto Scaling | なし |
| FR-12〜FR-14 | イベント駆動処理 | なし |
| FR-15〜FR-18 | 添付ファイル CRUD API | なし |
| FR-19 | マルチ環境管理 | なし |
| FR-20〜FR-24 | Observability | **変更**（Dashboard・Alarm 追加） |
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

### 新規

#### FR-56: API Gateway REST API

| 項目 | 内容 |
|------|------|
| ID | FR-56 |
| 概要 | API Gateway REST API を作成し、ALB の前段に API 管理レイヤーを配置する |
| API タイプ | REST API (API Gateway v1) |
| エンドポイント | REGIONAL（CloudFront 経由でアクセスするため EDGE 不要） |
| リソース | `/tasks`、`/tasks/{proxy+}`（プロキシリソース） |
| メソッド | ANY（全 HTTP メソッドを ALB にプロキシ） |
| 統合タイプ | HTTP_PROXY（ALB DNS への HTTP プロキシ統合） |
| 統合先 | `http://${ALB DNS}/tasks` および `http://${ALB DNS}/tasks/{proxy}` |
| API キー | `api_key_required = true` — 全メソッドで API キーを要求 |
| ステージ | `${env}`（dev / prod） |
| CloudWatch ログ | アクセスログ有効（JSON 形式） |
| Terraform リソース | `aws_api_gateway_rest_api`, `aws_api_gateway_resource`, `aws_api_gateway_method`, `aws_api_gateway_integration`, `aws_api_gateway_deployment`, `aws_api_gateway_stage`, `aws_api_gateway_account` |

#### FR-57: API Gateway キャッシュ

| 項目 | 内容 |
|------|------|
| ID | FR-57 |
| 概要 | API Gateway のステージキャッシュを有効化し、GET リクエストのレスポンスをキャッシュする |
| キャッシュ有効化 | ステージレベルで `cache_cluster_enabled = true` |
| キャッシュサイズ | `0.5` GB（最小サイズ、dev 環境用） |
| GET /tasks | キャッシュ有効、TTL = `var.apigw_cache_ttl`（デフォルト 300 秒） |
| GET /tasks/{id} | キャッシュ有効、TTL = `var.apigw_cache_ttl` |
| POST/PUT/DELETE | キャッシュ無効 |
| キャッシュキー | デフォルト（URL パス + クエリパラメータ） |
| Terraform リソース | `aws_api_gateway_method_settings` |
| 備考 | API Gateway キャッシュは HTTP レスポンス単位。アプリレベル Redis キャッシュとは独立した層 |

#### FR-58: Usage Plans + API Keys

| 項目 | 内容 |
|------|------|
| ID | FR-58 |
| 概要 | Usage Plan と API キーを作成し、API のアクセス制御と使用量管理を行う |
| Usage Plan | `${prefix}-usage-plan` |
| レート制限 | `var.apigw_throttle_rate_limit`（デフォルト 50 req/sec） |
| バースト制限 | `var.apigw_throttle_burst_limit`（デフォルト 100 req） |
| クォータ | `var.apigw_quota_limit`（デフォルト 10,000 req/日） |
| API キー | `${prefix}-api-key` |
| キーの注入方法 | CloudFront の `custom_header` で `x-api-key` を自動注入 |
| フロントエンド変更 | 不要（CloudFront が透過的にキーを注入） |
| Terraform リソース | `aws_api_gateway_usage_plan`, `aws_api_gateway_api_key`, `aws_api_gateway_usage_plan_key` |

#### FR-59: ElastiCache Redis

| 項目 | 内容 |
|------|------|
| ID | FR-59 |
| 概要 | ElastiCache Redis クラスタを作成し、アプリケーションレベルのキャッシュ基盤を提供する |
| エンジン | Redis 7.0 |
| ノードタイプ | `var.redis_node_type`（デフォルト `cache.t3.micro`、0.5 GB） |
| ノード数 | 1（単一ノード、dev 環境用） |
| サブネット | プライベートサブネット（private_1 + private_2） |
| セキュリティグループ | ECS タスク SG からの 6379 ポートのみ許可 |
| パラメータグループ | `default.redis7` |
| 暗号化 | なし（VPC 内通信、学習用） |
| ECS 環境変数 | `REDIS_URL=redis://{endpoint}:{port}` |
| Terraform リソース | `aws_elasticache_cluster`, `aws_elasticache_subnet_group` |

#### FR-60: アプリケーションレベルキャッシュ (Cache-aside)

| 項目 | 内容 |
|------|------|
| ID | FR-60 |
| 概要 | Redis を使った Cache-aside パターンで DB クエリ結果をキャッシュする |
| 新規ファイル | `app/services/cache.py` — Redis キャッシュサービス |
| キャッシュ対象 | GET /tasks（タスク一覧）、GET /tasks/{id}（個別タスク） |
| キーパターン | `tasks:list`（一覧）、`tasks:{id}`（個別） |
| TTL（一覧） | `CACHE_TTL_LIST` 環境変数（デフォルト 300 秒） |
| TTL（個別） | `CACHE_TTL_DETAIL` 環境変数（デフォルト 600 秒） |
| 無効化 | POST /tasks → `tasks:list` 削除。PUT/DELETE /tasks/{id} → `tasks:list` + `tasks:{id}` 削除 |
| シリアライズ | JSON（`json.dumps` / `json.loads`） |
| Graceful degradation | `REDIS_URL` 未設定 → キャッシュスキップ。Redis 接続失敗 → DB 直接アクセスにフォールバック |
| ライブラリ | `redis`（redis-py） |

#### FR-61: CloudFront オリジン変更

| 項目 | 内容 |
|------|------|
| ID | FR-61 |
| 概要 | CloudFront の `/tasks*` パスのオリジンを ALB から API Gateway に変更する |
| 変更対象 | `infra/webui.tf` — Origin 2 (`alb-api` → `apigw-api`) |
| オリジン URL | `${api_id}.execute-api.${region}.amazonaws.com` |
| オリジンパス | `/${env}`（API Gateway ステージ名） |
| プロトコル | `https-only`（API Gateway は HTTPS のみ） |
| API キー注入 | `custom_header` で `x-api-key` を設定 |
| キャッシュポリシー | CachingDisabled（API Gateway 側でキャッシュするため） |

#### FR-62: モニタリング拡張

| 項目 | 内容 |
|------|------|
| ID | FR-62 |
| 概要 | CloudWatch Dashboard と Alarms に API Gateway + ElastiCache メトリクスを追加する |
| Dashboard Row 6 | API Gateway: リクエスト数 + 5xx エラー、レイテンシ + CacheHitCount + CacheMissCount |
| Dashboard Row 7 | ElastiCache: CPU 使用率、接続数、Cache Hits/Misses + Evictions |
| 新規 Alarm | API Gateway 5xx（閾値 10）、API Gateway IntegrationLatency、Redis CPU（閾値 90%）、Redis Evictions（閾値 > 0） |
| 通知先 | 既存の SNS トピック（`alarm_notifications`） |

## 3. 非機能要件

### 既存（v9 から継続）

| ID | 概要 | 変更 |
|----|------|------|
| NFR-1 | 可用性 | なし |
| NFR-2 | セキュリティ | なし |
| NFR-3 | パフォーマンス | **向上**（Redis キャッシュ + API Gateway キャッシュ） |
| NFR-4 | 運用性 | **向上**（API 使用量の可視化、キャッシュメトリクス） |
| NFR-5 | コスト | 下記参照 |
| NFR-6 | スケーラビリティ | **向上**（キャッシュによる DB 負荷軽減） |
| NFR-7 | 疎結合性 | なし |
| NFR-8 | コンテンツ配信 | なし |
| NFR-9 | 可観測性 | **向上**（API Gateway + Redis メトリクス追加） |
| NFR-10 | 認証・認可 | なし |
| NFR-11 | DNS・ドメイン管理 | なし |
| NFR-12 | デプロイ戦略 | なし |
| NFR-13 | CI/CD セキュリティ | なし |

### 変更・追加

#### NFR-3: パフォーマンス（更新）

| 項目 | 内容 |
|------|------|
| ID | NFR-3 |
| API レスポンスキャッシュ | API Gateway ステージキャッシュで GET リクエストの応答を HTTP レベルでキャッシュ |
| DB クエリキャッシュ | Redis による Cache-aside パターンで RDS への読み取りクエリを削減 |
| キャッシュ TTL | 一覧: 300 秒、個別: 600 秒（変数で調整可能） |
| キャッシュ無効化 | 書き込み操作（POST/PUT/DELETE）で即時無効化 |

#### NFR-14: API 管理（新規）

| 項目 | 内容 |
|------|------|
| ID | NFR-14 |
| スロットリング | API Gateway でアカウント・ステージ・メソッドレベルのレート制限 |
| クォータ管理 | Usage Plan で日次 API コール数の上限を設定 |
| API キー | 外部アクセスの識別・制御。CloudFront 経由で透過的に注入 |
| 使用量追跡 | API Gateway メトリクスで使用量を可視化 |

#### NFR-15: キャッシュ耐障害性（新規）

| 項目 | 内容 |
|------|------|
| ID | NFR-15 |
| Redis 障害時 | DB 直接アクセスにフォールバック（Graceful degradation） |
| REDIS_URL 未設定 | キャッシュ機能をスキップ（ローカル開発対応） |
| 接続エラー | ログ出力のみ、リクエスト処理は継続 |

## 4. AWS 構成

| サービス | 用途 | v9 | v10 |
|----------|------|:--:|:--:|
| ECR | Docker イメージレジストリ | o | o |
| ECS (Fargate) | コンテナ実行環境 | o | o |
| ALB | ロードバランサー | o | o |
| VPC | ネットワーク | o | o |
| IAM | ロールとポリシー | o | o（**API Gateway CloudWatch ロール追加**） |
| CloudWatch Logs | ログ | o | o（**API Gateway アクセスログ追加**） |
| CloudWatch Dashboard | メトリクス統合表示 | o | o（**API Gateway + Redis メトリクス追加**） |
| CloudWatch Alarms | 障害検知 | o | o（**4 件追加: API GW 5xx, Latency, Redis CPU, Evictions**） |
| RDS (PostgreSQL) | データベース | o | o |
| Secrets Manager | クレデンシャル管理 | o | o |
| Auto Scaling | ECS タスク数自動調整 | o | o |
| SQS + DLQ | イベントキュー | o | o |
| Lambda | イベントハンドラ x 3 | o | o |
| EventBridge | イベントバス + Scheduler | o | o |
| VPC エンドポイント | Lambda 用 | o | o |
| S3 (attachments) | 添付ファイルストレージ | o | o |
| S3 (webui) | Web UI 静的ホスティング | o | o |
| S3 (terraform-state) | Terraform state 保存 | o | o |
| CloudFront (attachments) | 添付ファイル CDN | o | o |
| CloudFront (webui) | Web UI CDN + API プロキシ | o | o（**オリジン変更: ALB → API Gateway**） |
| SNS | アラーム通知 | o | o |
| X-Ray | 分散トレーシング | o | o |
| Cognito | ユーザー認証 | o | o |
| WAF v2 | Web Application Firewall | o | o |
| ACM | SSL/TLS 証明書 | o | o |
| Route 53 | DNS 管理 | o | o |
| DynamoDB (terraform-lock) | Terraform state ロック | o | o |
| CodeDeploy | B/G デプロイ管理 | o | o |
| IAM OIDC Provider | GitHub Actions キーレス認証 | o | o |
| **API Gateway (REST)** | **API 管理・スロットリング・キャッシュ** | - | **o** |
| **ElastiCache (Redis)** | **アプリレベル DB クエリキャッシュ** | - | **o** |

リージョン: **ap-northeast-1**（東京）
※ ACM 証明書・WAF WebACL は **us-east-1** に作成
※ API Gateway は **ap-northeast-1**（REGIONAL エンドポイント）

## 5. 技術スタック

| カテゴリ | 技術 | v9 | v10 |
|----------|------|:--:|:--:|
| 言語 (Backend) | Python 3.12 | o | o |
| フレームワーク | FastAPI | o | o |
| ORM | SQLAlchemy | o | o |
| AWS SDK (Python) | boto3 | o | o |
| JWT ライブラリ | python-jose[cryptography] | o | o |
| トレーシング | aws-xray-sdk | o | o |
| IaC | Terraform | o | o |
| CI/CD | GitHub Actions | o | o |
| Lint (Python) | ruff | o | o |
| テスト | pytest + moto | o | o |
| 言語 (Frontend) | JavaScript (JSX) | o | o |
| フレームワーク (Frontend) | React 19 | o | o |
| ビルドツール | Vite | o | o |
| 認証 SDK | amazon-cognito-identity-js | o | o |
| 脆弱性スキャン | Trivy | o | o |
| IaC セキュリティスキャン | tfsec | o | o |
| コスト見積もり | Infracost | o | o |
| デプロイ管理 | AWS CodeDeploy | o | o |
| **キャッシュクライアント** | **redis (redis-py)** | - | **o** |
| **テスト用 Redis** | **fakeredis** | - | **o** |

## 6. 環境変数

### アプリケーション環境変数の追加

| Variable | Where | Required | Description |
|----------|-------|----------|-------------|
| `REDIS_URL` | ECS | Optional | Redis 接続 URL。未設定→キャッシュスキップ |
| `CACHE_TTL_LIST` | ECS | Optional | タスク一覧キャッシュ TTL（秒）。デフォルト 300 |
| `CACHE_TTL_DETAIL` | ECS | Optional | 個別タスクキャッシュ TTL（秒）。デフォルト 600 |

### Terraform 変数の追加

| Variable | 説明 | デフォルト |
|----------|------|-----------|
| `redis_node_type` | ElastiCache Redis ノードタイプ | `cache.t3.micro` |
| `redis_port` | Redis ポート番号 | `6379` |
| `apigw_cache_ttl` | API Gateway キャッシュ TTL（秒） | `300` |
| `apigw_throttle_rate_limit` | API Gateway スロットリング（req/sec） | `50` |
| `apigw_throttle_burst_limit` | API Gateway バースト制限 | `100` |
| `apigw_quota_limit` | Usage Plan クォータ（リクエスト数） | `10000` |
| `apigw_quota_period` | Usage Plan クォータ期間 | `DAY` |
| `app_cache_ttl_list` | アプリキャッシュ TTL（一覧、秒） | `300` |
| `app_cache_ttl_detail` | アプリキャッシュ TTL（個別、秒） | `600` |

### GitHub Secrets / Variables の変更

変更なし。

## 7. コスト見積もり

| 項目 | 月額 |
|------|------|
| 既存インフラ（v9 まで） | 約 $98〜99 |
| API Gateway REST API | 約 $3.50/100 万リクエスト（低トラフィックなら < $1） |
| API Gateway キャッシュ (0.5 GB) | 約 $14/月 |
| ElastiCache Redis (cache.t3.micro) | 約 $13/月 |
| CloudWatch Logs (API Gateway) | < $1/月 |
| **v10 全体合計** | **約 $126〜128/月** |

※ API Gateway キャッシュと ElastiCache が主なコスト増加要因（合計 +約 $27〜29/月）
※ 学習完了後はキャッシュクラスタを停止することでコスト削減可能

## 8. 前提条件・制約

### 前提条件

- v9 の全成果物が完成済みであること
- CodeDeploy B/G デプロイが正常動作していること
- CloudFront + ALB のルーティングが正常動作していること
- VPC のプライベートサブネットが RDS で使用されていること（ElastiCache も同じサブネットを使用）

### 制約

- API Gateway REST API のキャッシュは 0.5 GB が最小サイズ（約 $14/月のコスト）
- ElastiCache `cache.t3.micro` は Free Tier 対象だが、既に RDS で Free Tier を使用している場合は課金される
- API Gateway の HTTP プロキシ統合は ALB の DNS 名を直接参照するため、ALB の再作成時は API Gateway 側の設定更新が必要
- Redis は単一ノード構成のため、ノード障害時はキャッシュが消失する（Graceful degradation で対応）
- API Gateway のステージキャッシュとアプリレベル Redis キャッシュは独立した 2 層。データの整合性は個別に管理
- CloudFront の `custom_header` で API キーを注入するため、CloudFront を経由しない直接アクセスは API キーが必要

## 9. 実装方針

### 9.1 アーキテクチャ変更

```
【v9】 Route 53 → CloudFront (WAF) → ALB → ECS → RDS

【v10】 Route 53 → CloudFront (WAF)
          ├─ /tasks*  → API Gateway (REST, REGIONAL) → ALB → ECS → Redis → RDS
          └─ /*       → S3 (Web UI)
```

### 9.2 キャッシュの 2 層設計

| 層 | 技術 | キャッシュ対象 | TTL | 無効化 |
|----|------|-------------|-----|--------|
| L1 | API Gateway ステージキャッシュ | HTTP レスポンス | 300 秒 | TTL 満了のみ |
| L2 | ElastiCache Redis | DB クエリ結果 | 300〜600 秒 | 書き込み操作で即時削除 |

L1（API Gateway）は HTTP レイヤーでのキャッシュ、L2（Redis）はアプリケーションレイヤーでのキャッシュ。L1 がヒットすれば ECS まで到達しない。L1 がミスしても L2 がヒットすれば RDS まで到達しない。

### 9.3 Terraform ファイル構成の変更

```
infra/
  apigateway.tf     # 新規: REST API, リソース, メソッド, 統合, ステージ, Usage Plan, API キー
  elasticache.tf    # 新規: Redis クラスタ, サブネットグループ
  security_groups.tf # 変更: Redis SG 追加
  variables.tf      # 変更: v10 変数追加
  dev.tfvars        # 変更: v10 値追加
  prod.tfvars       # 変更: v10 値追加
  ecs.tf            # 変更: REDIS_URL 環境変数追加
  webui.tf          # 変更: Origin ALB → API Gateway
  monitoring.tf     # 変更: Dashboard 2 行 + Alarm 4 件追加
  outputs.tf        # 変更: API Gateway, Redis 出力追加
  iam.tf            # 変更: API Gateway CloudWatch ロール追加
```

### 9.4 アプリケーションファイル構成の変更

```
app/
  services/
    cache.py        # 新規: Redis キャッシュサービス
  routers/
    tasks.py        # 変更: Cache-aside パターン統合
  requirements.txt  # 変更: redis 追加
```

## 10. 用語集（v10 追加分）

| 用語 | 説明 |
|------|------|
| API Gateway REST API | AWS のフルマネージド API 管理サービス。リソース・メソッド定義、スロットリング、キャッシュ、Usage Plans を提供 |
| REGIONAL エンドポイント | API Gateway のエンドポイントタイプ。同一リージョンからのアクセスに最適化。CloudFront と組み合わせる場合に使用 |
| HTTP プロキシ統合 | API Gateway がリクエストをそのまま HTTP バックエンド（ALB 等）に転送する統合タイプ。リクエスト/レスポンスの変換なし |
| Usage Plan | API Gateway の使用量管理機能。API キーに対してスロットリング（レート制限）とクォータ（日次/月次上限）を設定 |
| API Key | API Gateway へのアクセスを識別するキー。`x-api-key` ヘッダーで送信。Usage Plan と紐付けてアクセス制御 |
| ステージキャッシュ | API Gateway のビルトインキャッシュ機能。GET リクエストのレスポンスをメモリにキャッシュし、バックエンドへのリクエストを削減 |
| ElastiCache | AWS のフルマネージドインメモリキャッシュサービス。Redis または Memcached をサポート |
| Cache-aside パターン | キャッシュ読み取りパターン。キャッシュをチェック → ミスなら DB から取得 → キャッシュに保存 → レスポンス返却 |
| TTL (Time to Live) | キャッシュエントリの有効期間。TTL 経過後にエントリが自動的に無効化される |
| キャッシュ無効化 | データ変更時にキャッシュエントリを明示的に削除すること。データの整合性を保つために必要 |
| Graceful degradation | 一部のコンポーネントが障害を起こしても、機能を縮退させてサービスを継続する設計パターン |
| Eviction | キャッシュメモリが不足した際に、既存エントリを削除して新しいエントリのスペースを確保すること |
