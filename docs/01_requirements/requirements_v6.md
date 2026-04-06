# 要件定義書 (v6)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-06 |
| バージョン | 6.0 |
| 前バージョン | [requirements_v5.md](requirements_v5.md) (v5.0) |

## 変更概要

v5（ストレージ + マルチ環境）に以下を追加する:

- **Observability（監視・可観測性）**: CloudWatch Dashboard / Alarms、SNS 通知基盤、X-Ray 分散トレーシング、構造化ログ
- **Web UI（SPA）**: React + Vite で構築した管理画面を S3 + CloudFront でホスティング。フロントエンド CI/CD パイプライン

## 1. プロジェクト概要

### 1.1 目的

v5 で構築したタスク管理 API + ファイルストレージ基盤に、本番運用に不可欠な **監視・可観測性** 機能と、
ブラウザからタスクを操作できる **Web UI** を追加する。
CloudWatch の統合ダッシュボード・アラーム、X-Ray による分散トレーシング、構造化ログによる
ログ分析基盤を学習する。また React SPA を S3 + CloudFront でホスティングし、
フロントエンドの CI/CD パイプライン（ビルド → S3 sync → CloudFront invalidation）を構築する。

### 1.2 学習目標

| # | 学習テーマ | 内容 | デプロイ |
|---|-----------|------|:---:|
| 1 | CloudWatch Dashboard | ECS / ALB / RDS / Lambda / SQS メトリクスの統合ビュー | ✅ |
| 2 | CloudWatch Alarms | 障害検知のためのアラーム設定（閾値・評価期間・アクション） | ✅ |
| 3 | SNS | アラーム通知基盤（Topic 作成。メールサブスクリプションは後から追加可能） | ✅ |
| 4 | AWS X-Ray | 分散トレーシング（FastAPI + Lambda、サイドカー daemon） | ✅ |
| 5 | 構造化ログ | JSON フォーマットログと CloudWatch Logs Insights クエリ | ✅ |
| 6 | React + Vite | SPA の構築とビルドパイプライン | ✅ |
| 7 | S3 静的ホスティング + CloudFront | SPA の CDN 配信（OAC、SPA ルーティング対応） | ✅ |
| 8 | CORS | クロスオリジンリクエスト制御（FastAPI ミドルウェア） | ✅ |
| 9 | フロントエンド CI/CD | npm build → S3 sync → CloudFront invalidation | ✅ |

### 1.3 スコープ

**スコープ内:**

- CloudWatch Dashboard（ECS / ALB / RDS / Lambda / SQS メトリクスの統合表示）
- CloudWatch Alarms（12 個: ALB / ECS / RDS / Lambda / SQS 系）
- SNS Topic 作成（アラーム通知先。メールサブスクリプションは空 — 後から追加可能）
- X-Ray 分散トレーシング
  - ECS: aws-xray-sdk + サイドカー daemon コンテナ
  - Lambda: Active tracing（Terraform 設定のみ）
- 構造化ログ（JSON フォーマット）: FastAPI アプリ + Lambda 関数
- CloudWatch Logs Insights サンプルクエリ（ドキュメント）
- Web UI（React + Vite SPA）
  - タスク一覧（completed / pending フィルタ）
  - タスク作成・編集・削除・完了切替
  - 添付ファイルアップロード（Presigned URL フロー）
  - 添付ファイル一覧・ダウンロード
- Web UI ホスティング（S3 バケット + CloudFront ディストリビューション: Web UI 専用）
- FastAPI CORS ミドルウェア
- CI/CD パイプライン拡張
  - CI: Node.js セットアップ + フロントエンドビルド
  - CD: フロントエンド S3 sync + CloudFront invalidation

**スコープ外:**

- APM ツール連携（Datadog / New Relic 等）
- カスタムメトリクス（CloudWatch PutMetricData）
- Composite Alarms（複合アラーム）
- CloudWatch Synthetics（外形監視）
- CloudWatch RUM（リアルユーザーモニタリング）
- SNS メールサブスクリプション（Topic のみ作成、購読は手動追加）
- Slack / PagerDuty 連携
- API 認証・認可（Cognito / JWT）
- WebSocket（リアルタイム通知）
- SSR（サーバーサイドレンダリング）
- E2E テスト（Playwright / Cypress）
- フロントエンドユニットテスト（Jest / Vitest）
- `prod` 環境への実デプロイ（tfvars ファイルの更新のみ）

## 2. 機能要件

### 既存（v5 から継続）

| ID | 概要 | 変更 |
|----|------|------|
| FR-1 | Hello World API (`GET /`) | なし |
| FR-2 | ヘルスチェック (`GET /health`) | なし |
| FR-3 | CI パイプライン | Node.js セットアップ + フロントエンドビルドを追加 |
| FR-4 | CD パイプライン | フロントエンド S3 sync + CloudFront invalidation を追加 |
| FR-5 | タスク一覧取得 (`GET /tasks`) | なし |
| FR-6 | タスク作成 (`POST /tasks`) | なし |
| FR-7 | タスク個別取得 (`GET /tasks/{id}`) | なし |
| FR-8 | タスク更新 (`PUT /tasks/{id}`) | なし |
| FR-9 | タスク削除 (`DELETE /tasks/{id}`) | なし |
| FR-10 | データベース永続化 | なし |
| FR-11 | ECS Auto Scaling | なし |
| FR-12 | タスク作成イベント通知（SQS） | なし |
| FR-13 | タスク完了イベント通知（EventBridge） | なし |
| FR-14 | 定期クリーンアップ（Scheduler） | なし |
| FR-15 | ファイルアップロード（Presigned URL） | なし |
| FR-16 | 添付ファイル一覧取得 | なし |
| FR-17 | 添付ファイル取得（CloudFront URL） | なし |
| FR-18 | 添付ファイル削除 | なし |
| FR-19 | マルチ環境管理（Terraform Workspace） | なし |

### 新規

#### FR-20: CloudWatch Dashboard

| 項目 | 内容 |
|------|------|
| ID | FR-20 |
| 概要 | AWS リソースのメトリクスを統合表示するダッシュボードを作成する |
| ウィジェット構成 | ALB (RequestCount, 5XX, ResponseTime) / ECS (CPU, Memory, RunningTaskCount) / RDS (CPU, FreeStorageSpace, Connections) / Lambda (Invocations, Errors, Duration) / SQS (MessagesSent, MessagesVisible for Main + DLQ) |
| 期間 | 各ウィジェットはデフォルト 5 分間隔で表示 |
| Terraform リソース | `aws_cloudwatch_dashboard` |

#### FR-21: CloudWatch Alarms

| 項目 | 内容 |
|------|------|
| ID | FR-21 |
| 概要 | 障害検知のためのアラームを設定する（12 個） |
| アラーム一覧 | ALB: 5xx エラー数 / Unhealthy hosts / 高レイテンシ。ECS: CPU 高 / Memory 高。RDS: CPU 高 / ストレージ低下 / 接続数過多。Lambda: エラー数 / スロットル / 実行時間。SQS: DLQ メッセージ |
| 閾値 | dev / prod で異なる値を tfvars で制御 |
| アクション | SNS Topic への通知 |
| Terraform リソース | `aws_cloudwatch_metric_alarm` × 12 |

**アラーム閾値一覧:**

| アラーム | メトリクス | 比較 | 閾値 (dev) | 閾値 (prod) | 期間 | 評価回数 |
|---------|-----------|------|-----------|-------------|------|---------|
| ALB 5xx | HTTPCode_Target_5XX_Count | >= | 10 | 5 | 60s | 3 |
| ALB Unhealthy | UnHealthyHostCount | >= | 1 | 1 | 60s | 2 |
| ALB Latency | TargetResponseTime (avg) | >= | 3.0s | 1.0s | 60s | 3 |
| ECS CPU | CPUUtilization (avg) | >= | 90% | 80% | 300s | 2 |
| ECS Memory | MemoryUtilization (avg) | >= | 90% | 80% | 300s | 2 |
| RDS CPU | CPUUtilization (avg) | >= | 90% | 80% | 300s | 2 |
| RDS Storage | FreeStorageSpace | <= | 2 GB | 5 GB | 300s | 1 |
| RDS Connections | DatabaseConnections | >= | 50 | 100 | 300s | 2 |
| Lambda Errors | Errors (sum) | >= | 5 | 3 | 300s | 1 |
| Lambda Throttles | Throttles (sum) | >= | 1 | 1 | 300s | 1 |
| Lambda Duration | Duration (avg) | >= | 10000ms | 5000ms | 300s | 2 |
| SQS DLQ | ApproximateNumberOfMessagesVisible | >= | 1 | 1 | 300s | 1 |

#### FR-22: SNS 通知基盤

| 項目 | 内容 |
|------|------|
| ID | FR-22 |
| 概要 | CloudWatch Alarms の通知先となる SNS Topic を作成する |
| 構成 | SNS Topic のみ作成。サブスクリプション（メールアドレス）は空 |
| 拡張方法 | `alarm_email` 変数にメールアドレスを設定すると自動的にサブスクリプションが作成される |
| Terraform リソース | `aws_sns_topic`, `aws_sns_topic_subscription` (conditional) |

#### FR-23: X-Ray 分散トレーシング

| 項目 | 内容 |
|------|------|
| ID | FR-23 |
| 概要 | ALB → ECS → AWS 各サービスのリクエストをトレースする |
| ECS 統合 | aws-xray-sdk (Python) + サイドカー daemon コンテナ (`amazon/aws-xray-daemon`) |
| Lambda 統合 | `tracing_config { mode = "Active" }` (Terraform 設定のみ) |
| 自動計装 | boto3, sqlalchemy を `patch_all()` で自動パッチ |
| Graceful degradation | `ENABLE_XRAY` 環境変数が未設定または daemon 不在の場合、アプリは正常動作を継続 |
| IAM | ECS タスクロール + Lambda 3 ロールに `xray:PutTraceSegments`, `xray:PutTelemetryRecords` 等を追加 |
| ECS タスク定義変更 | サイドカーコンテナ追加に伴い CPU / Memory を引き上げ (dev: 512/1024) |

#### FR-24: 構造化ログ

| 項目 | 内容 |
|------|------|
| ID | FR-24 |
| 概要 | JSON フォーマットの構造化ログを出力し、CloudWatch Logs Insights でクエリ可能にする |
| 対象 | FastAPI アプリ (ECS) + Lambda 関数 (3 つ) |
| 出力フィールド | `timestamp`, `level`, `logger`, `message`, `exception` (例外時), `xray_trace_id` (X-Ray 有効時) |
| 実装方式 | Python `logging.Formatter` のサブクラス (`JSONFormatter`) |
| 外部依存 | なし（標準ライブラリのみ） |

#### FR-25: Web UI — タスク一覧

| 項目 | 内容 |
|------|------|
| ID | FR-25 |
| 概要 | ブラウザからタスクの一覧を確認する |
| API 呼び出し | `GET /tasks` |
| 表示項目 | タイトル、完了状態、作成日時 |
| フィルタ | 全て / 未完了 / 完了 の切り替え |
| 操作 | タスク作成画面への遷移、各タスクの詳細画面への遷移 |

#### FR-26: Web UI — タスク作成

| 項目 | 内容 |
|------|------|
| ID | FR-26 |
| 概要 | ブラウザからタスクを新規作成する |
| API 呼び出し | `POST /tasks` |
| 入力項目 | タイトル（必須、1-255 文字）、説明（任意） |
| 作成後 | タスク詳細画面に遷移 |
| バリデーション | タイトル空欄時にエラー表示 |

#### FR-27: Web UI — タスク詳細・編集・削除・完了

| 項目 | 内容 |
|------|------|
| ID | FR-27 |
| 概要 | タスクの詳細表示、編集、削除、完了切替を行う |
| API 呼び出し | `GET /tasks/{id}`, `PUT /tasks/{id}`, `DELETE /tasks/{id}` |
| 表示項目 | タイトル、説明、完了状態、作成日時、更新日時 |
| 操作 | タイトル・説明の編集、完了 / 未完了の切替、削除（確認ダイアログ付き） |
| 削除後 | タスク一覧画面に遷移 |

#### FR-28: Web UI — 添付ファイルアップロード

| 項目 | 内容 |
|------|------|
| ID | FR-28 |
| 概要 | タスク詳細画面からファイルをアップロードする |
| フロー | ファイル選択 → `POST /tasks/{id}/attachments` → Presigned URL 取得 → `PUT` で S3 に直接アップロード |
| 許可 content_type | `image/jpeg`, `image/png`, `image/gif`, `application/pdf`, `text/plain` |
| エラー時 | 非対応 content_type の場合はエラーメッセージを表示 |
| アップロード後 | 添付ファイル一覧を更新 |

#### FR-29: Web UI — 添付ファイル一覧・ダウンロード

| 項目 | 内容 |
|------|------|
| ID | FR-29 |
| 概要 | タスク詳細画面で添付ファイルを一覧表示し、ダウンロードする |
| API 呼び出し | `GET /tasks/{id}/attachments`, `GET /tasks/{id}/attachments/{att_id}` |
| 表示項目 | ファイル名、content_type、サイズ、作成日時 |
| ダウンロード | CloudFront URL を新しいタブで開く |
| 削除 | 各ファイルに削除ボタン（`DELETE /tasks/{id}/attachments/{att_id}`） |

#### FR-30: CORS ミドルウェア

| 項目 | 内容 |
|------|------|
| ID | FR-30 |
| 概要 | Web UI (CloudFront ドメイン) から API への クロスオリジンリクエストを許可する |
| 実装 | FastAPI の `CORSMiddleware` |
| 設定ソース | 環境変数 `CORS_ALLOWED_ORIGINS`（カンマ区切り）。未設定時はデフォルト `*` |
| 許可メソッド | GET, POST, PUT, DELETE, OPTIONS |
| 許可ヘッダー | `*` |
| dev 設定 | `allow_origins = ["*"]` |
| prod 設定 | `allow_origins = ["https://{webui_cloudfront_domain}"]` |

#### FR-31: フロントエンド CI/CD

| 項目 | 内容 |
|------|------|
| ID | FR-31 |
| 概要 | フロントエンドのビルドとデプロイを CI/CD パイプラインに追加する |
| CI | Node.js 20 セットアップ → `npm ci` → `npm run build` |
| CD | API URL 注入 (`config.js` 生成) → `aws s3 sync dist/` → `aws cloudfront create-invalidation` |
| API URL 注入方式 | CD パイプラインで ALB DNS 名を取得し、`frontend/dist/config.js` に書き出す |
| トリガー | 既存と同じ（main push で CD 実行） |

## 3. 非機能要件

### 既存（v5 から継続）

| ID | 概要 | 変更 |
|----|------|------|
| NFR-1 | 可用性 | なし |
| NFR-2 | セキュリティ | X-Ray IAM 権限追加、CORS 設定追加 |
| NFR-3 | パフォーマンス | X-Ray トレーシングで可視化。Web UI は CloudFront でキャッシュ配信 |
| NFR-4 | 運用性 | Dashboard / Alarms / 構造化ログで大幅改善 |
| NFR-5 | コスト | 下記参照 |
| NFR-6 | スケーラビリティ | なし |
| NFR-7 | 疎結合性 | なし |
| NFR-8 | コンテンツ配信 | Web UI 用に 2 つ目の CloudFront ディストリビューション追加 |

### 変更・追加

#### NFR-4: 運用性（更新）

| 項目 | 内容 |
|------|------|
| ID | NFR-4 |
| ダッシュボード | 全サービスメトリクスを 1 画面で確認可能 |
| アラーム | 12 個の閾値アラームで障害を検知。SNS Topic 経由で通知可能 |
| トレーシング | X-Ray でリクエスト単位のレイテンシとエラーを追跡 |
| ログ分析 | 構造化ログ (JSON) + CloudWatch Logs Insights でフィルタ・集計 |

#### NFR-5: コスト（更新）

| 項目 | 内容 |
|------|------|
| ID | NFR-5 |
| CloudWatch Dashboard | $3.00/月（ダッシュボード 1 つ） |
| CloudWatch Alarms | 標準アラーム: $0.10/個/月 × 12 = **$1.20/月** |
| X-Ray | 無料枠: 月 10 万トレース記録 + 100 万トレース取得 → 学習用は実質 **$0** |
| SNS | Topic 作成は無料。メール通知: 月 1,000 件まで無料 → 実質 **$0** |
| CloudFront (Web UI) | 無料枠: 月 1 TB + 1,000 万リクエスト → 実質 **$0** |
| ECS CPU/Memory 増加 | dev: 256/512 → 512/1024（X-Ray sidecar 分）→ 追加 **約 $10/月** |
| v6 追加分合計 | 約 **$14.20/月** |
| 全体合計概算 | 約 **$89/月**（v5 $75 + v6 $14.20） |

#### NFR-9: 可観測性（新規）

| 項目 | 内容 |
|------|------|
| ID | NFR-9 |
| MTTD (平均検知時間) | アラーム評価期間に依存（最短 2 分、最長 10 分） |
| MTTR (平均復旧時間) | ダッシュボード + X-Ray で根本原因の特定を迅速化 |
| ログ保持 | dev: 7 日、prod: 30 日（既存設定を継続） |
| トレースサンプリング | X-Ray デフォルト（1 秒あたり 1 リクエスト + 5% のリザーバ） |

## 4. AWS 構成

| サービス | 用途 | v5 | v6 |
|----------|------|:--:|:--:|
| ECR | Docker イメージレジストリ | o | o |
| ECS (Fargate) | コンテナ実行環境 | o | o（X-Ray sidecar 追加） |
| ALB | ロードバランサー | o | o |
| VPC | ネットワーク | o | o |
| IAM | ロールとポリシー | o | o（X-Ray 権限追加） |
| CloudWatch Logs | コンテナ・Lambda ログ | o | o（X-Ray daemon ログ追加） |
| RDS (PostgreSQL) | データベース Multi-AZ | o | o |
| Secrets Manager | クレデンシャル管理 | o | o |
| Application Auto Scaling | ECS タスク数自動調整 | o | o |
| SQS | タスク作成イベントキュー | o | o |
| SQS (DLQ) | 失敗メッセージの退避 | o | o |
| Lambda | イベントハンドラ（3 関数） | o | o（Active tracing 追加） |
| EventBridge | タスク完了イベントバス + ルール | o | o |
| EventBridge Scheduler | 定期クリーンアップ実行 | o | o |
| VPC エンドポイント | Lambda から AWS サービスへのアクセス | o | o |
| S3 (attachments) | ファイル添付のオブジェクトストレージ | o | o |
| CloudFront (attachments) | CDN（添付ファイル配信） | o | o |
| **CloudWatch Dashboard** | メトリクス統合表示 | - | **o** |
| **CloudWatch Alarms** | 障害検知（12 個） | - | **o** |
| **SNS** | アラーム通知基盤 | - | **o** |
| **X-Ray** | 分散トレーシング | - | **o** |
| **S3 (webui)** | Web UI 静的アセットホスティング | - | **o** |
| **CloudFront (webui)** | Web UI CDN 配信 | - | **o** |

リージョン: **ap-northeast-1**（東京）

## 5. 技術スタック

| カテゴリ | 技術 | v5 | v6 |
|----------|------|:--:|:--:|
| 言語 (Backend) | Python 3.12 | o | o |
| フレームワーク | FastAPI | o | o（CORS 追加） |
| ORM | SQLAlchemy | o | o |
| マイグレーション | Alembic | o | o |
| DB ドライバ | psycopg2-binary | o | o |
| AWS SDK (Python) | boto3 | o | o |
| **トレーシング** | **aws-xray-sdk** | - | **o** |
| IaC | Terraform | o | o（Monitoring / SNS / WebUI 追加） |
| CI/CD | GitHub Actions | o | o（Node.js + Frontend deploy 追加） |
| コンテナ | Docker | o | o |
| Lint (Python) | ruff | o | o |
| テスト | pytest + moto | o | o |
| **言語 (Frontend)** | **JavaScript (JSX)** | - | **o** |
| **フレームワーク (Frontend)** | **React 19** | - | **o** |
| **ビルドツール** | **Vite** | - | **o** |
| **UI コンポーネント** | **21st-magic MCP / shadcn/ui** | - | **o** |
| **ランタイム (Frontend)** | **Node.js 20** | - | **o** |

## 6. 前提条件・制約

### 前提条件

- v5 の全成果物が完成済みであること
- AWS アカウントが利用可能であること
- GitHub リポジトリが利用可能であること
- Node.js 20 がローカル環境にインストールされていること

### 制約

- AWS リージョンは ap-northeast-1（東京）固定
- Terraform Workspace で `dev` / `prod` の 2 環境を管理（実デプロイは `dev` のみ）
- X-Ray は `ENABLE_XRAY` 環境変数で有効化制御。未設定時はスキップ（graceful degradation）
- 構造化ログは標準ライブラリのみで実装（外部パッケージ不使用）
- SNS はメールサブスクリプションなしで Topic のみ作成（後から追加可能）
- Web UI は React + Vite で構築。ビルド成果物を S3 にデプロイ
- Web UI の API URL は CD パイプラインで動的注入（`config.js` 方式）
- API 認証・認可は v6 スコープ外（全エンドポイントがパブリック）
- フロントエンドのテスト（Jest / Vitest / E2E）は v6 スコープ外
- Lambda のデプロイは zip パッケージ形式（v5 と同様）
- `prod` 環境への実デプロイは行わない（tfvars ファイルの更新のみ）

## 7. 用語集（v6 追加分）

| 用語 | 説明 |
|------|------|
| CloudWatch Dashboard | AWS の各サービスメトリクスをウィジェットで統合表示するカスタムダッシュボード |
| CloudWatch Alarm | メトリクスが閾値を超えた際に状態遷移（OK → ALARM）し、SNS 等にアクションを発行する仕組み |
| SNS (Simple Notification Service) | Pub/Sub モデルの通知サービス。Topic にメッセージを発行すると、全サブスクリプション（メール、Lambda 等）に配信される |
| AWS X-Ray | 分散トレーシングサービス。リクエストがサービスを横断する際の経路・レイテンシ・エラーを可視化する |
| X-Ray Daemon | トレースデータをバッファリングして X-Ray API に送信するデーモンプロセス。ECS ではサイドカーコンテナとして配置 |
| X-Ray Segment / Subsegment | X-Ray のトレース単位。Segment はサービス全体、Subsegment は内部の個別呼び出し（DB クエリ、外部 API 等）を表す |
| 構造化ログ | JSON 等の機械可読フォーマットで出力されるログ。CloudWatch Logs Insights で高度なクエリが可能 |
| CloudWatch Logs Insights | CloudWatch Logs に対してクエリ言語でフィルタ・集計・可視化を行うサービス |
| CORS (Cross-Origin Resource Sharing) | ブラウザのセキュリティ制約により、異なるオリジン（ドメイン）間の HTTP リクエストを制御する仕組み |
| SPA (Single Page Application) | 初回ロード時に全ての HTML / CSS / JS をダウンロードし、以降はページ遷移なしで動的にコンテンツを切り替える Web アプリケーション |
| Vite | 高速なフロントエンドビルドツール。ES Modules ベースの開発サーバーと Rollup ベースのプロダクションビルドを提供 |
| React | Meta（旧 Facebook）が開発したコンポーネントベースの UI ライブラリ。JSX でコンポーネントを宣言的に記述する |
| shadcn/ui | Tailwind CSS ベースの再利用可能な UI コンポーネントコレクション。コピー＆ペーストで使用するため依存パッケージにならない |
| CloudFront Invalidation | CloudFront のエッジキャッシュを無効化し、オリジンから最新コンテンツを再取得させる操作 |
| S3 sync | ローカルディレクトリと S3 バケットの差分を検出し、変更のあるファイルのみをアップロード / 削除する AWS CLI コマンド |
