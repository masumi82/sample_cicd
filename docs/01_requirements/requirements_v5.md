# 要件定義書 (v5)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-06 |
| バージョン | 5.0 |
| 前バージョン | [requirements_v4.md](requirements_v4.md) (v4.0) |

## 変更概要

v4（イベント駆動アーキテクチャ）に以下を追加する:

- タスクへのファイル添付機能（S3 + Presigned URL でアップロード、CloudFront 経由でダウンロード）
- Terraform Workspace によるマルチ環境管理（dev / prod）

## 1. プロジェクト概要

### 1.1 目的

v4 で構築したイベント駆動タスク管理 API にファイルストレージ機能を追加する。
S3 を使ったオブジェクトストレージの基本操作、Presigned URL によるセキュアなファイルアップロード、
CloudFront CDN を使ったコンテンツ配信、そして Terraform Workspace によるマルチ環境管理を学習する。

### 1.2 学習目標

| # | 学習テーマ | 内容 | デプロイ |
|---|-----------|------|:---:|
| 1 | S3 | オブジェクトストレージの基本（バケット作成、オブジェクト操作、バケットポリシー） | ✅ |
| 2 | Presigned URL | 署名付き URL による期限付きセキュアアップロード | ✅ |
| 3 | CloudFront | CDN によるコンテンツ配信（OAC を使った S3 プライベートアクセス） | ✅ |
| 4 | Origin Access Control (OAC) | CloudFront から S3 へのセキュアなオリジンアクセス制御 | ✅ |
| 5 | Terraform Workspace | 同一コードで dev / prod 環境を切り替えるマルチ環境管理 | ✅（dev のみ） |
| 6 | 環境別 tfvars | 環境ごとに異なるパラメータ（インスタンスサイズ等）を管理する方法 | ✅ |

### 1.3 スコープ

**スコープ内:**

- タスクへのファイル添付 API（4 エンドポイント）
  - Presigned URL の生成（PUT 用: S3 へ直接アップロード）
  - CloudFront URL の返却（ダウンロード）
  - 添付ファイルの一覧・取得・削除
- S3 バケットの作成（プライベート、パブリックアクセス全ブロック）
- CloudFront ディストリビューションの作成（OAC で S3 にアクセス）
- `attachments` テーブルの追加（Alembic マイグレーション）
- Terraform Workspace で `dev` / `prod` 環境を管理
  - 環境別 `.tfvars` ファイル（`dev.tfvars`, `prod.tfvars`）
  - 全リソース名に環境名を含める
- CI/CD パイプラインの Workspace 対応

**スコープ外:**

- ファイルバージョニング（S3 versioning）
- マルチパートアップロード（大容量ファイル対応）
- ウイルス / マルウェアスキャン
- サムネイル生成（画像リサイズ）
- CloudFront 署名付き URL / Cookie（ダウンロード制限）
- CloudFront カスタムドメイン / HTTPS（v3 同様コードのみ）
- WAF（Web Application Firewall）
- S3 イベント通知（アップロード完了時の Lambda 呼び出し等）
- S3 クロスリージョンレプリケーション
- リモート Terraform state（S3 backend + DynamoDB ロック）
- `prod` 環境への実デプロイ（tfvars ファイルの作成のみ）

## 2. 機能要件

### 既存（v4 から継続）

| ID | 概要 | 変更 |
|----|------|------|
| FR-1 | Hello World API (`GET /`) | なし |
| FR-2 | ヘルスチェック (`GET /health`) | なし |
| FR-3 | CI パイプライン | Workspace 対応の lint / test 追加 |
| FR-4 | CD パイプライン | Workspace 対応のデプロイコマンドに変更 |
| FR-5 | タスク一覧取得 (`GET /tasks`) | なし |
| FR-6 | タスク作成 (`POST /tasks`) | なし |
| FR-7 | タスク個別取得 (`GET /tasks/{id}`) | なし |
| FR-8 | タスク更新 (`PUT /tasks/{id}`) | なし |
| FR-9 | タスク削除 (`DELETE /tasks/{id}`) | タスク削除時に関連添付ファイルの S3 オブジェクトも削除 |
| FR-10 | データベース永続化 | `attachments` テーブル追加 |
| FR-11 | ECS Auto Scaling | なし |
| FR-12 | タスク作成イベント通知（SQS） | なし |
| FR-13 | タスク完了イベント通知（EventBridge） | なし |
| FR-14 | 定期クリーンアップ（Scheduler） | なし |

### 新規

#### FR-15: ファイルアップロード（Presigned URL 生成）

| 項目 | 内容 |
|------|------|
| ID | FR-15 |
| 概要 | タスクにファイルを添付するための Presigned PUT URL を生成する |
| エンドポイント | `POST /tasks/{task_id}/attachments` |
| リクエストボディ | `{ "filename": "screenshot.png", "content_type": "image/png" }` |
| レスポンス | `201 Created` `{ "id": 1, "upload_url": "https://s3.../...?X-Amz-...", "filename": "screenshot.png", "status": "pending" }` |
| S3 キー構造 | `tasks/{task_id}/{uuid}-{filename}` |
| Presigned URL 有効期限 | 300 秒（5 分） |
| 許可 content_type | `image/jpeg`, `image/png`, `image/gif`, `application/pdf`, `text/plain` |
| ファイルサイズ上限 | 10 MB |
| task_id 不存在時 | `404 Not Found` |
| S3 未設定時 | `503 Service Unavailable`（環境変数 `S3_BUCKET_NAME` 未設定） |

#### FR-16: 添付ファイル一覧取得

| 項目 | 内容 |
|------|------|
| ID | FR-16 |
| 概要 | タスクに添付されたファイルの一覧を取得する |
| エンドポイント | `GET /tasks/{task_id}/attachments` |
| レスポンス | `200 OK` `[{ "id": 1, "filename": "screenshot.png", "content_type": "image/png", "file_size": 102400, "created_at": "..." }]` |
| task_id 不存在時 | `404 Not Found` |

#### FR-17: 添付ファイル取得（CloudFront URL 付き）

| 項目 | 内容 |
|------|------|
| ID | FR-17 |
| 概要 | 添付ファイルのメタデータと CloudFront ダウンロード URL を取得する |
| エンドポイント | `GET /tasks/{task_id}/attachments/{attachment_id}` |
| レスポンス | `200 OK` `{ "id": 1, "filename": "screenshot.png", "content_type": "image/png", "file_size": 102400, "download_url": "https://d1234.cloudfront.net/tasks/1/abc-screenshot.png", "created_at": "..." }` |
| download_url 構成 | `https://{CLOUDFRONT_DOMAIN_NAME}/{s3_key}` |
| task_id 不存在時 | `404 Not Found` |
| attachment_id 不存在時 | `404 Not Found` |

#### FR-18: 添付ファイル削除

| 項目 | 内容 |
|------|------|
| ID | FR-18 |
| 概要 | 添付ファイルを S3 とデータベースから削除する |
| エンドポイント | `DELETE /tasks/{task_id}/attachments/{attachment_id}` |
| 処理 | S3 オブジェクト削除 → DB レコード削除 |
| レスポンス | `204 No Content` |
| task_id 不存在時 | `404 Not Found` |
| attachment_id 不存在時 | `404 Not Found` |
| S3 削除失敗時 | 警告ログのみ記録。DB レコードは削除する（S3 オーファンは許容） |

#### FR-19: マルチ環境管理（Terraform Workspace）

| 項目 | 内容 |
|------|------|
| ID | FR-19 |
| 概要 | Terraform Workspace を使い、同一コードで複数環境を管理する |
| 環境 | `dev`（開発）、`prod`（本番） |
| リソース命名規則 | `sample-cicd-{env}-{リソース名}`（例: `sample-cicd-dev-alb-sg`） |
| 環境別パラメータファイル | `dev.tfvars`, `prod.tfvars` |
| 状態ファイル | Workspace ごとに分離（`terraform.tfstate.d/{env}/terraform.tfstate`） |
| デプロイ対象 | `dev` のみ実デプロイ。`prod` は tfvars ファイルのみ作成 |

**環境別パラメータ差分:**

| パラメータ | dev | prod |
|-----------|-----|------|
| ECS CPU / Memory | 256 / 512 | 512 / 1024 |
| ECS タスク数（min/max） | 1 / 2 | 2 / 4 |
| RDS インスタンスクラス | db.t3.micro | db.t3.small |
| RDS Multi-AZ | false | true |
| CloudFront Price Class | PriceClass_100 | PriceClass_200 |
| ログ保持期間 | 7 日 | 30 日 |

## 3. 非機能要件

### 既存（v4 から継続）

| ID | 概要 | 変更 |
|----|------|------|
| NFR-1 | 可用性 | なし |
| NFR-3 | パフォーマンス | CloudFront による静的ファイル配信で改善 |
| NFR-4 | 運用性 | なし |
| NFR-6 | スケーラビリティ | なし |
| NFR-7 | 疎結合性 | なし |

### 変更・追加

#### NFR-2: セキュリティ（更新）

| 項目 | 内容 |
|------|------|
| ID | NFR-2 |
| S3 バケット | パブリックアクセス全ブロック。バケットポリシーで CloudFront OAC のみ `s3:GetObject` を許可 |
| Presigned URL | PUT のみ生成。有効期限 300 秒。content_type ホワイトリスト制限 |
| CloudFront OAC | S3 への直接アクセスを禁止し、CloudFront 経由のみに制限 |
| ECS タスクロール | `s3:PutObject`, `s3:DeleteObject` 権限を追加（対象バケットに限定） |
| CORS | S3 バケットに CORS 設定（PUT メソッドのみ許可） |

#### NFR-5: コスト（更新）

| 項目 | 内容 |
|------|------|
| ID | NFR-5 |
| S3 Standard | $0.025/GB/月 → 学習用は数 MB のため実質 **$0** |
| S3 リクエスト | PUT: $0.005/1000 件、GET: $0.0004/1000 件 → 実質 **$0** |
| CloudFront | 無料枠: 月 1 TB 転送 + 1,000 万リクエスト → 実質 **$0** |
| 既存リソース | v4 と同等（VPC エンドポイント含む約 $75） |
| 合計概算 | 約 **$75**/月（S3 / CloudFront は無料枠内） |
| 注意 | CloudFront ディストリビューションは削除に時間がかかる（最大 15 分）。学習完了後は早めに削除を開始すること |

#### NFR-8: コンテンツ配信（新規）

| 項目 | 内容 |
|------|------|
| ID | NFR-8 |
| CDN | CloudFront を使用。エッジロケーションからの配信でレイテンシ低減 |
| キャッシュ | CloudFront デフォルト TTL を使用。添付ファイルは変更不可（イミュータブル）のため長期キャッシュ可能 |
| Price Class | dev: `PriceClass_100`（北米・欧州のみ、最安）。prod: `PriceClass_200`（+アジア） |
| オリジン | S3 バケット（OAC 経由） |

## 4. AWS 構成

| サービス | 用途 | v4 | v5 |
|----------|------|:--:|:--:|
| ECR | Docker イメージレジストリ | o | o |
| ECS (Fargate) | コンテナ実行環境 | o | o |
| ALB | ロードバランサー | o | o |
| VPC | ネットワーク | o | o |
| IAM | ロールとポリシー | o | o（更新） |
| CloudWatch Logs | コンテナ・Lambda ログ | o | o |
| RDS (PostgreSQL) | データベース Multi-AZ | o | o |
| Secrets Manager | クレデンシャル管理 | o | o |
| Application Auto Scaling | ECS タスク数自動調整 | o | o |
| SQS | タスク作成イベントキュー | o | o |
| SQS (DLQ) | 失敗メッセージの退避 | o | o |
| Lambda | イベントハンドラ（3 関数） | o | o |
| EventBridge | タスク完了イベントバス + ルール | o | o |
| EventBridge Scheduler | 定期クリーンアップ実行 | o | o |
| VPC エンドポイント | Lambda から AWS サービスへのアクセス | o | o |
| **S3** | ファイル添付のオブジェクトストレージ | - | **o** |
| **CloudFront** | CDN（S3 コンテンツ配信） | - | **o** |

リージョン: **ap-northeast-1**（東京）

## 5. 技術スタック

| カテゴリ | 技術 | v4 | v5 |
|----------|------|:--:|:--:|
| 言語 | Python 3.12 | o | o |
| フレームワーク | FastAPI | o | o |
| ORM | SQLAlchemy | o | o |
| マイグレーション | Alembic | o | o |
| DB ドライバ | psycopg2-binary | o | o |
| AWS SDK | boto3 | o | o（S3 操作追加） |
| IaC | Terraform | o | o（Workspace 追加） |
| CI/CD | GitHub Actions | o | o（更新） |
| コンテナ | Docker | o | o |
| Lint | ruff | o | o |
| テスト | pytest + moto | o | o（S3 モック追加） |

## 6. 前提条件・制約

### 前提条件

- v4 の全成果物が完成済みであること
- AWS アカウントが利用可能であること
- GitHub リポジトリが利用可能であること

### 制約

- AWS リージョンは ap-northeast-1（東京）固定
- Terraform Workspace で `dev` / `prod` の 2 環境を管理（実デプロイは `dev` のみ）
- ファイルアップロードは Presigned URL 経由（API サーバーを経由しない）
- ファイルダウンロードは CloudFront 経由（S3 直接アクセス不可）
- ファイルサイズ上限は 10 MB（マルチパートアップロードは使用しない）
- 許可する content_type はホワイトリスト制限
- S3 バケットはパブリックアクセス全ブロック
- v4 リソースは `terraform destroy` 後に v5 で再デプロイ（Workspace 移行のため）
- Lambda のデプロイは zip パッケージ形式（v4 と同様）
- Lambda 関数コードは `lambda/` ディレクトリで管理（v4 と同様）

## 7. 用語集（v5 追加分）

| 用語 | 説明 |
|------|------|
| S3 (Simple Storage Service) | AWS のオブジェクトストレージサービス。任意のファイルをバケットに保存・取得できる |
| S3 バケット | S3 のトップレベルコンテナ。グローバルに一意な名前が必要 |
| Presigned URL（署名付き URL） | S3 の特定オブジェクトに対して、一時的なアクセス権限を持つ URL。有効期限付きでセキュアなアップロード / ダウンロードを実現 |
| CloudFront | AWS の CDN（Content Delivery Network）サービス。世界中のエッジロケーションにコンテンツをキャッシュし、低レイテンシで配信する |
| OAC (Origin Access Control) | CloudFront が S3 にアクセスする際の認証メカニズム。従来の OAI の後継で、AWS が推奨する方式 |
| OAI (Origin Access Identity) | CloudFront → S3 アクセスの旧方式。OAC に置き換えられた（非推奨） |
| CDN (Content Delivery Network) | コンテンツをエッジサーバーにキャッシュし、ユーザーに近い場所から配信する仕組み |
| Terraform Workspace | 同一の Terraform コードで複数の環境（dev / prod 等）を管理する仕組み。環境ごとに独立した状態ファイルを持つ |
| tfvars ファイル | Terraform の変数値を定義するファイル。環境ごとに異なるパラメータを管理するために使用する |
| Price Class | CloudFront のエッジロケーション範囲を制限してコストを抑える設定。100（北米・欧州）、200（+アジア）、All（全リージョン） |
