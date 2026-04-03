# 要件定義書 (v2)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-03 |
| バージョン | 2.0 |
| 前バージョン | [requirements.md](requirements.md) (v1.0) |

## 変更概要

v1（Hello World API）に以下を追加する:
- RDS PostgreSQL によるデータ永続化
- タスク管理 CRUD API（5 エンドポイント）
- Secrets Manager によるクレデンシャル管理
- プライベートサブネットの導入

## 1. プロジェクト概要

### 1.1 目的

v1 で構築した ECS Fargate + CI/CD パイプライン基盤の上に、
RDS PostgreSQL を追加してデータベース連携の設計・実装・デプロイを学習する。

### 1.2 学習目標

| # | 学習テーマ | 内容 |
|---|-----------|------|
| 1 | RDS | PostgreSQL インスタンスの構築と接続 |
| 2 | プライベートサブネット | DB をインターネットから隔離するネットワーク設計 |
| 3 | Secrets Manager | DB クレデンシャルの安全な管理と ECS への注入 |
| 4 | SQLAlchemy | Python ORM によるデータベース操作 |
| 5 | Alembic | データベースマイグレーション管理 |
| 6 | CRUD API | RESTful な API エンドポイント設計 |

### 1.3 スコープ

**スコープ内:**
- タスク管理 CRUD API の開発（FastAPI + SQLAlchemy）
- RDS PostgreSQL のプロビジョニング（Terraform）
- プライベートサブネットの追加
- Secrets Manager による DB クレデンシャル管理
- Alembic によるマイグレーション管理
- 既存 CI/CD パイプラインの拡張

**スコープ外（v1 から変更なし）:**
- ユーザー認証・認可
- カスタムドメイン・SSL 証明書（ACM）
- 複数環境（staging / production）の分離
- Auto Scaling の設定
- RDS Multi-AZ 構成
- NAT Gateway

## 2. 機能要件

### 既存（v1 から継続）

| ID | 概要 | 変更 |
|----|------|------|
| FR-1 | Hello World API (`GET /`) | なし |
| FR-2 | ヘルスチェック (`GET /health`) | なし |
| FR-3 | CI パイプライン | Docker ビルドコンテキスト変更 |
| FR-4 | CD パイプライン | ECS タスク定義に Secrets Manager 統合 |

### 新規

### FR-5: タスク一覧取得

| 項目 | 内容 |
|------|------|
| ID | FR-5 |
| 概要 | 登録済みタスクの一覧を取得する |
| エンドポイント | `GET /tasks` |
| レスポンス | タスクオブジェクトの配列 |
| ステータスコード | 200 OK |

### FR-6: タスク作成

| 項目 | 内容 |
|------|------|
| ID | FR-6 |
| 概要 | 新しいタスクを作成する |
| エンドポイント | `POST /tasks` |
| リクエストボディ | `{"title": "string", "description": "string or null"}` |
| レスポンス | 作成されたタスクオブジェクト |
| ステータスコード | 201 Created |

### FR-7: タスク個別取得

| 項目 | 内容 |
|------|------|
| ID | FR-7 |
| 概要 | 指定 ID のタスクを取得する |
| エンドポイント | `GET /tasks/{id}` |
| レスポンス | タスクオブジェクト |
| ステータスコード | 200 OK / 404 Not Found |

### FR-8: タスク更新

| 項目 | 内容 |
|------|------|
| ID | FR-8 |
| 概要 | 指定 ID のタスクを更新する |
| エンドポイント | `PUT /tasks/{id}` |
| リクエストボディ | `{"title": "string", "description": "string", "completed": bool}` (各フィールド任意) |
| レスポンス | 更新後のタスクオブジェクト |
| ステータスコード | 200 OK / 404 Not Found |

### FR-9: タスク削除

| 項目 | 内容 |
|------|------|
| ID | FR-9 |
| 概要 | 指定 ID のタスクを削除する |
| エンドポイント | `DELETE /tasks/{id}` |
| レスポンス | なし |
| ステータスコード | 204 No Content / 404 Not Found |

### FR-10: データベース永続化

| 項目 | 内容 |
|------|------|
| ID | FR-10 |
| 概要 | タスクデータを RDS PostgreSQL に永続化する |
| 要件 | ECS タスクの再起動後もデータが保持されること |
| DB エンジン | PostgreSQL 15 |
| ORM | SQLAlchemy |
| マイグレーション | Alembic |

## 3. 非機能要件

### 既存（v1 から継続）

| ID | 概要 | 変更 |
|----|------|------|
| NFR-1 | 可用性 | なし |
| NFR-3 | パフォーマンス | なし |
| NFR-4 | 運用性 | なし |

### 変更

### NFR-2: セキュリティ（更新）

| 項目 | 内容 |
|------|------|
| ID | NFR-2 |
| IAM | ECS タスク実行ロールに Secrets Manager 読み取り権限を追加 |
| コンテナ | 非 root ユーザーで実行（変更なし） |
| シークレット | DB クレデンシャルは Secrets Manager で管理。ECS タスク定義の `secrets` ブロックで注入 |
| ネットワーク | RDS はプライベートサブネットに配置。ECS タスクからのみ port 5432 でアクセス可能 |
| イメージスキャン | ECR のイメージスキャンを有効化（変更なし） |
| パスワード | Terraform の `random_password` で自動生成（16 文字以上） |

### NFR-5: コスト（更新）

| 項目 | 内容 |
|------|------|
| ID | NFR-5 |
| 方針 | 学習用のため最小構成で運用 |
| Fargate | 0.25 vCPU / 512 MB（変更なし） |
| RDS | db.t3.micro / Single-AZ / 20 GB gp2（約 $15/月） |
| Secrets Manager | 1 シークレット（約 $0.40/月） |
| 概算合計 | 約 $45/月（ALB + Fargate + RDS + Secrets Manager） |
| 注意 | **学習完了後はリソースを確実に削除すること**（特に RDS は時間課金） |

## 4. AWS 構成

| サービス | 用途 | v1 | v2 |
|----------|------|:--:|:--:|
| ECR | Docker イメージレジストリ | o | o |
| ECS (Fargate) | コンテナ実行環境 | o | o |
| ALB | ロードバランサー | o | o |
| VPC | ネットワーク | o | o |
| IAM | ロールとポリシー | o | o |
| CloudWatch Logs | コンテナログ | o | o |
| RDS (PostgreSQL) | データベース | - | **o** |
| Secrets Manager | クレデンシャル管理 | - | **o** |

リージョン: **ap-northeast-1**（東京）

## 5. 技術スタック

| カテゴリ | 技術 | v1 | v2 |
|----------|------|:--:|:--:|
| 言語 | Python 3.12 | o | o |
| フレームワーク | FastAPI | o | o |
| ORM | SQLAlchemy | - | **o** |
| マイグレーション | Alembic | - | **o** |
| DB ドライバ | psycopg2-binary | - | **o** |
| IaC | Terraform | o | o |
| CI/CD | GitHub Actions | o | o |
| コンテナ | Docker | o | o |
| Lint | ruff | o | o |
| テスト | pytest | o | o |

## 6. 前提条件・制約

### 前提条件

- v1 の全成果物が完成済みであること
- AWS アカウントが利用可能であること
- GitHub リポジトリが利用可能であること
- ローカル環境に Docker がインストール済みであること

### 制約

- AWS リージョンは ap-northeast-1（東京）固定
- 環境は本番（production）のみ
- HTTPS 対応はスコープ外
- RDS は Single-AZ（学習用最小構成）
- RDS バックアップは無効（学習用のため）
- NAT Gateway は使用しない（コスト削減）

## 7. 用語集（v2 追加分）

| 用語 | 説明 |
|------|------|
| RDS | Relational Database Service。マネージドリレーショナルデータベース |
| PostgreSQL | オープンソースのリレーショナルデータベース |
| Secrets Manager | AWS のシークレット管理サービス。クレデンシャルの安全な保存と自動ローテーション |
| SQLAlchemy | Python の ORM（Object-Relational Mapping）ライブラリ |
| Alembic | SQLAlchemy 用のデータベースマイグレーションツール |
| CRUD | Create, Read, Update, Delete の頭文字。データ操作の基本 4 操作 |
| プライベートサブネット | インターネットゲートウェイへのルートを持たないサブネット。外部から直接アクセスできない |
| DB Subnet Group | RDS インスタンスが使用するサブネットのグループ。複数 AZ のサブネットを指定 |
