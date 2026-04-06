# 要件定義書 (v4)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-06 |
| バージョン | 4.0 |
| 前バージョン | [requirements_v3.md](requirements_v3.md) (v3.0) |

## 変更概要

v3（ECS Auto Scaling + HTTPS準備）に以下を追加する:

- タスク作成時に SQS へメッセージ送信 → Lambda でログ記録
- タスク完了時に EventBridge カスタムバスへイベント発行 → Lambda でログ記録
- EventBridge Scheduler による定期クリーンアップ → Lambda が RDS から古い完了済みタスクを削除

## 1. プロジェクト概要

### 1.1 目的

v3 で構築したタスク管理 API にイベント駆動アーキテクチャを追加する。
タスクの作成・完了・定期処理を SQS / EventBridge / Lambda の組み合わせで非同期化し、
疎結合なシステム設計パターンを学習する。

### 1.2 学習目標

| # | 学習テーマ | 内容 | デプロイ |
|---|-----------|------|:---:|
| 1 | SQS | メッセージキューイングの基本（送信・受信・DLQ） | ✅ |
| 2 | Lambda (SQS トリガー) | SQS メッセージをトリガーに Lambda を実行する | ✅ |
| 3 | EventBridge カスタムイベントバス | アプリケーションカスタムイベントの発行とルーティング | ✅ |
| 4 | Lambda (EventBridge トリガー) | EventBridge ルールをトリガーに Lambda を実行する | ✅ |
| 5 | EventBridge Scheduler | cron ベースの定期実行スケジュール設定 | ✅ |
| 6 | Lambda (Scheduler トリガー + VPC) | VPC 内 RDS に接続する Lambda の設定 | ✅ |
| 7 | Lambda IAM ロール | Lambda 関数ごとの最小権限 IAM ロール設計 | ✅ |
| 8 | DLQ (Dead Letter Queue) | 処理失敗時のメッセージ退避と再処理設計 | ✅ |

### 1.3 スコープ

**スコープ内:**

- FastAPI へのイベント発行コード追加（boto3 による SQS / EventBridge への送信）
- Lambda 関数 3 つ（Python 3.12）の実装
  - `task_created_handler`: SQS トリガー → CloudWatch Logs に記録
  - `task_completed_handler`: EventBridge トリガー → CloudWatch Logs に記録
  - `task_cleanup_handler`: EventBridge Scheduler トリガー → RDS から古い完了済みタスクを削除（VPC 内配置）
- SQS Dead Letter Queue の設定（最大 3 回リトライ後に DLQ へ転送）
- Terraform による全リソース管理

**スコープ外:**

- SNS / メール / Slack 等の外部通知
- Lambda のカナリアデプロイ・バージョン管理
- X-Ray による分散トレーシング
- Lambda Layers の利用
- マルチ環境（staging / production）対応

## 2. 機能要件

### 既存（v3 から継続）

| ID | 概要 | 変更 |
|----|------|------|
| FR-1 | Hello World API (`GET /`) | なし |
| FR-2 | ヘルスチェック (`GET /health`) | なし |
| FR-3 | CI パイプライン | Lambda パッケージビルドを追加 |
| FR-4 | CD パイプライン | Lambda デプロイ（`aws lambda update-function-code`）を追加 |
| FR-5 | タスク一覧取得 (`GET /tasks`) | なし |
| FR-6 | タスク作成 (`POST /tasks`) | SQS 送信を追加 |
| FR-7 | タスク個別取得 (`GET /tasks/{id}`) | なし |
| FR-8 | タスク更新 (`PUT /tasks/{id}`) | completed=true 変化時に EventBridge 送信を追加 |
| FR-9 | タスク削除 (`DELETE /tasks/{id}`) | なし |
| FR-10 | データベース永続化 | なし（RDS Multi-AZ 継続） |
| FR-11 | ECS Auto Scaling | なし |

### 新規

#### FR-12: タスク作成イベント通知（SQS）

| 項目 | 内容 |
|------|------|
| ID | FR-12 |
| 概要 | タスク作成時に SQS へメッセージを送信し、Lambda でログ記録する |
| トリガー | `POST /tasks` の DB 保存成功後 |
| メッセージ内容 | `{ "event": "task_created", "task_id": 1, "title": "..." }` |
| Lambda 処理 | CloudWatch Logs へ記録（ロググループ: `/aws/lambda/sample-cicd-task-created`） |
| 失敗時 | DLQ（`sample-cicd-task-events-dlq`）に転送、最大 3 回リトライ |
| 非同期性 | SQS 送信失敗は警告ログのみ記録。API レスポンスはブロックしない |

#### FR-13: タスク完了イベント通知（EventBridge）

| 項目 | 内容 |
|------|------|
| ID | FR-13 |
| 概要 | タスクが完了（`completed=true`）に更新された際に EventBridge へイベントを発行し Lambda で処理する |
| トリガー | `PUT /tasks/{id}` で `completed` が `false → true` に変化した時 |
| カスタムイベントバス | `sample-cicd-bus` |
| イベント内容 | `source: "sample-cicd"`, `detail-type: "TaskCompleted"`, `detail: { task_id, title }` |
| Lambda 処理 | CloudWatch Logs へ記録（ロググループ: `/aws/lambda/sample-cicd-task-completed`） |
| completed=false の場合 | EventBridge 送信はスキップ |

#### FR-14: 定期クリーンアップ（EventBridge Scheduler）

| 項目 | 内容 |
|------|------|
| ID | FR-14 |
| 概要 | 定期的に完了後 30 日以上経過したタスクを RDS から削除する |
| スケジュール | 毎日 0:00 JST（UTC: `cron(0 15 * * ? *)`） |
| Lambda 処理 | `completed=true AND updated_at < now() - 30日` のタスクを削除し、削除件数を CloudWatch Logs へ記録 |
| Lambda 配置 | VPC 内プライベートサブネット（RDS への直接接続が必要なため） |
| DB 接続 | Secrets Manager から認証情報を取得して RDS に接続 |

## 3. 非機能要件

### 既存（v3 から継続）

| ID | 概要 | 変更 |
|----|------|------|
| NFR-1 | 可用性 | なし |
| NFR-3 | パフォーマンス | なし |
| NFR-4 | 運用性 | CloudWatch Logs に Lambda ログが追加 |
| NFR-6 | スケーラビリティ | なし |

### 変更・追加

#### NFR-2: セキュリティ（更新）

| 項目 | 内容 |
|------|------|
| ID | NFR-2 |
| Lambda IAM | 関数ごとに専用 IAM ロールを作成し最小権限を付与 |
| SQS | ECS タスクに SQS 送信権限、Lambda に SQS 受信・削除権限のみ付与 |
| EventBridge | ECS タスクに EventBridge PutEvents 権限のみ付与 |
| Secrets Manager | cleanup Lambda に Secrets Manager GetSecretValue 権限付与 |

#### NFR-5: コスト（更新）

| 項目 | 内容 |
|------|------|
| ID | NFR-5 |
| Lambda | 無料枠（月 100 万リクエスト・40 万 GB-秒）内 |
| SQS | 無料枠（月 100 万リクエスト）内 |
| EventBridge | カスタムイベント $1/100 万イベント → 実質 $0 |
| VPC エンドポイント | cleanup Lambda が VPC 内から Secrets Manager / CloudWatch Logs にアクセスするために必要。$0.01/h × 2 = 約 **+$15**/月 |
| 合計概算 | 約 **$75**/月（v3 の $60 から +$15） |
| 注意 | **VPC エンドポイントのコストに注意。学習完了後は必ずリソースを削除すること** |

#### NFR-7: 疎結合性（新規）

| 項目 | 内容 |
|------|------|
| ID | NFR-7 |
| SQS | FastAPI と Lambda の間を非同期に疎結合化。SQS 送信失敗は API レスポンスに影響しない |
| EventBridge | イベント発行元（FastAPI）と処理先（Lambda）が独立。将来的にルールを追加するだけで処理先を増やせる |
| DLQ | 処理失敗メッセージを DLQ に退避し、手動再処理や調査を可能にする |

## 4. AWS 構成

| サービス | 用途 | v3 | v4 |
|----------|------|:--:|:--:|
| ECR | Docker イメージレジストリ | o | o |
| ECS (Fargate) | コンテナ実行環境 | o | o |
| ALB | ロードバランサー | o | o |
| VPC | ネットワーク | o | o（更新） |
| IAM | ロールとポリシー | o | o（更新） |
| CloudWatch Logs | コンテナ・Lambda ログ | o | o（更新） |
| RDS (PostgreSQL) | データベース Multi-AZ | o | o |
| Secrets Manager | クレデンシャル管理 | o | o |
| Application Auto Scaling | ECS タスク数自動調整 | o | o |
| **SQS** | タスク作成イベントキュー | - | **o** |
| **SQS (DLQ)** | 失敗メッセージの退避 | - | **o** |
| **Lambda** | イベントハンドラ（3 関数） | - | **o** |
| **EventBridge** | タスク完了イベントバス + ルール | - | **o** |
| **EventBridge Scheduler** | 定期クリーンアップ実行 | - | **o** |
| **VPC エンドポイント** | cleanup Lambda から Secrets Manager / CloudWatch Logs へのアクセス | - | **o** |

リージョン: **ap-northeast-1**（東京）

## 5. 技術スタック

| カテゴリ | 技術 | v3 | v4 |
|----------|------|:--:|:--:|
| 言語 | Python 3.12 | o | o |
| フレームワーク | FastAPI | o | o |
| ORM | SQLAlchemy | o | o |
| マイグレーション | Alembic | o | o |
| DB ドライバ | psycopg2-binary | o | o |
| AWS SDK | boto3 | - | **o** |
| IaC | Terraform | o | o |
| CI/CD | GitHub Actions | o | o（更新） |
| コンテナ | Docker | o | o |
| Lint | ruff | o | o |
| テスト | pytest + moto | o | o（更新） |

## 6. 前提条件・制約

### 前提条件

- v3 の全成果物が完成済みであること
- AWS アカウントが利用可能であること
- GitHub リポジトリが利用可能であること

### 制約

- AWS リージョンは ap-northeast-1（東京）固定
- 環境は本番（production）のみ
- SQS / EventBridge 送信失敗は API レスポンスをブロックしない（ベストエフォート送信）
- cleanup Lambda は VPC 内配置（RDS への直接接続が必要）
- NAT Gateway は使用しない（VPC エンドポイント経由で AWS サービスにアクセス）
- Lambda のデプロイは zip パッケージ形式（コンテナイメージ不使用）
- Lambda 関数コードは `lambda/` ディレクトリで管理

## 7. 用語集（v4 追加分）

| 用語 | 説明 |
|------|------|
| SQS (Simple Queue Service) | AWS のフルマネージドメッセージキューサービス。送信者と受信者を非同期に疎結合化する |
| DLQ (Dead Letter Queue) | 処理に失敗したメッセージを退避するための専用キュー |
| Lambda | AWS のサーバーレスコンピューティングサービス。コードをアップロードするだけで実行環境が自動管理される |
| EventBridge | AWS のサーバーレスイベントバスサービス。イベントの発行・ルーティング・フィルタリングを管理する |
| EventBridge Scheduler | cron 式または rate 式で Lambda 等を定期実行できる AWS サービス |
| カスタムイベントバス | AWS 標準のイベントバス（default）とは別に作成する、アプリケーション専用のイベントバス |
| VPC エンドポイント | VPC 内から NAT Gateway を使わずに AWS サービス（S3, SQS 等）にプライベートアクセスする仕組み |
| moto | AWS サービスをモックするための Python テストライブラリ |
| イベント駆動アーキテクチャ | 処理のトリガーをイベントとして表現し、イベント発行者と処理者を疎結合に繋ぐ設計パターン |
