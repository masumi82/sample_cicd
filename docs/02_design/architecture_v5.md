# アーキテクチャ設計書 (v5)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-06 |
| バージョン | 5.0 |
| 前バージョン | [architecture_v4.md](architecture_v4.md) (v4.0) |

## 変更概要

v4 のアーキテクチャに以下を追加する:

- タスクへのファイル添付機能（S3 + Presigned URL + CloudFront）
- Terraform Workspace によるマルチ環境管理（全リソース名に環境名を付与）

## 1. システム構成図

```
                         ┌──────────���────────────────���──────────────────────────────────────────────┐
                         │                   AWS Cloud (ap-northeast-1) — Workspace: dev            │
                         │                                                                          │
  ┌──────────┐           │  ┌──────────────────────────────────────────────────────────────────────┐│
  │  User     │──HTTP──▶ │  │                   VPC (10.0.0.0/16)                                  ││
  │ (Browser) │          │  │                                                                      ││
  └──────┬───┘           │  │  ┌──────────────────────────────────────────────────────────────┐   ││
         │               │  │  │  Public Subnets (AZ-a / AZ-c)                                │   ││
         ���               │  │  │                                                              │   ││
         │               │  │  │  ┌─────┐     ┌────────────────────────────────────────────┐ │   ││
         │               │  │  │  │ ALB │────▶│  ECS Fargate (Auto Scaling 1〜2 tasks)     │ │   │���
         │               │  │  │  │ :80 │     │  FastAPI + Tasks + Attachments              │ │   ││
         │               ��  │  │  └─────┘     │    │POST /tasks ─────────────────────────┼─┼───┼─┼──▶ SQS
         │               │  │  │              │    │PUT /tasks/{id} (completed) ──────────┼─┼───┼─┼──▶ EventBridge
         │               │  │  │              │    │POST /tasks/{id}/attachments ─────────��─┼───┼─┼──▶ S3 (Presigned URL 生成)
         │               │  │  │              │    │DELETE /tasks/{id}/attachments/{id} ──┼─┼──���┼─┼──▶ S3 (DeleteObject)
         │               ���  │  │              └────┼───────────────────────────────────────┘ │   ││
         │               │  │  │                   │ :5432                                   │   ││
         │               │  │  └───────────────────┼────────────��─────────────────────────────┘   ││
         │               │  │                      │                                               ││
         │               │  │  ┌───────────────────┼──────────���───────────────────────────────┐   ││
         │               │  │  │  Private Subnets (AZ-a / AZ-c)                               │   │��
         │               │  │  │                   │                                          │   ││
         │               │  │  │    ┌──────────────▼──────────────────────────────────────┐  │   ││
         │               │  │  │    │  RDS PostgreSQL (dev: Single-AZ)                    │  │   ││
         │               │  │  │    │  + attachments table (v5)                           │  │   ││
         │               │  │  │    └──────────────────────────────────────���──────────────┘  │   ││
         │               │  │  │                           ▲ :5432                           │   ││
         │               │  │  │    ┌──────────────────────┘                                 │   ││
         │               │  │  │    │  task_cleanup_handler (Lambda in VPC)                  │   ││
         │               │  │  │    │  ← EventBridge Scheduler (cron)                        │   ││
         │               │  │  │    │  → Secrets Manager VPC Endpoint                        │   ││
         │               │  │  │    ��  → CloudWatch Logs VPC Endpoint                        │   ││
         │               │  │  └────┼───────���─────────────────────────────────��─────────────┘   ││
         │               │  └───────┼───────────────────────────────────────────────────────────┘│
         │               │          │                                                             │
         │  Presigned    │  ┌───────┼───────────────────────────────────────────────────────────┐│
         │  PUT URL      │  │  AWS Managed Services                                             ││
         │    │          │  │                                                                   ││
         │    ▼          │  │  S3 ──────────────────────────────────────────────────────────┐  ││
         │  ┌──────┐     │  │  └── sample-cicd-dev-attachments (Private bucket)             │  ││
         └──│  S3  │     │  │       └── tasks/{task_id}/{uuid}-{filename}                   │  ││
            │Upload│     │  │                              │ OAC                            │  ││
            └──────┘     │  │                              ▼                                │  ││
                         │  │  CloudFront ─────────────── S3 Origin ─────────────────────────┘  ││
  ┌──────────┐           │  │  └── sample-cicd-dev (Distribution)                               ││
  │  User     │─HTTPS──▶ │  │       └── Origin Access Control (OAC) でセキュア接続              ││
  │(Download) │          │  │                                                                   ││
  └──────────┘           │  │  SQS ──────────────────▶ task_created_handler (Lambda)            ││
                         │  ���  EventBridge ──────────▶ task_completed_handler (Lambda)           ││
                         │  │  EventBridge Scheduler ▶ task_cleanup_handler (Lambda, VPC)        ││
                         │  │                                                                   ││
                         │  │  Secrets Manager, CloudWatch Logs, App AutoScaling, ECR           ││
                         │  └───────────────��───────────────────────────────────────────────────┘│
                         └──────────────────────────────────────────────────────────────────────┘
                                  ▲
  ┌──��───────┐   ┌──────────────┐ │
  │  GitHub   │──▶│GitHub Actions│─┘  (CI/CD: Workspace 対応)
  │  (push)   │   └──────────────┘
  └──────────┘
```

## 2. コンポーネント一覧

### v4 から継続

| コンポーネ��ト | 役割 | v5 変更 |
|----------------|------|---------|
| FastAPI Application | API 提供 | 添付ファイル CRUD ルーター追加（attachments.py, services/storage.py） |
| ALB | HTTP リクエスト受付・分散 | なし |
| ECS (Fargate) | コンテナ実行環境 | S3 権限追加、環境変数追加（S3_BUCKET_NAME, CLOUDFRONT_DOMAIN_NAME） |
| ECR | Docker イメージ保存 | なし |
| GitHub Actions | CI/CD パイプライン | Workspace 対応のデプロイコマンドに変更 |
| CloudWatch Logs | ログ収集 | なし |
| RDS PostgreSQL | データ永続化 | `attachments` テーブル追加 |
| Secrets Manager | DB クレデンシャル管理 | なし |
| Application Auto Scaling | ECS タスク数自動調整 | なし |
| SQS | タスク作成イベントキュー | なし |
| Lambda (3 関数) | イベントハンドラ | なし |
| EventBridge | イベントバス + ルール + Scheduler | なし |
| VPC Endpoints | Lambda → AWS サービスアクセ�� | なし |
| Terraform | インフラコード管理 | Workspace 対応 + S3 / CloudFront リソース追加 |

### v5 新規

| コンポーネント | 役割 | 対応要件 |
|----------------|------|----------|
| S3 Bucket | ファイル添付のオブジェクトストレージ（プライベート） | FR-15, FR-18 |
| CloudFront Distribution | CDN（S3 からのコンテンツ配信） | FR-17 |
| Origin Access Control (OAC) | CloudFront → S3 のセキュアアクセス制御 | FR-17, NFR-2 |
| Terraform Workspace | dev / prod マルチ環境管理 | FR-19 |

## 3. ネットワーク構成

### 3.1 VPC 設計（変更なし）

| 項目 | 値 | v5 変更 |
|------|------|---------|
| VPC CIDR | 10.0.0.0/16 | なし |
| パブリックサブネット 1 | 10.0.1.0/24 (ap-northeast-1a) | なし |
| パブリックサ���ネット 2 | 10.0.2.0/24 (ap-northeast-1c) | なし |
| プライベートサブネット 1 | 10.0.11.0/24 (ap-northeast-1a) | なし |
| プライベートサブネット 2 | 10.0.12.0/24 (ap-northeast-1c) | なし |
| Internet Gateway | あ�� | なし |
| NAT Gateway | なし（コスト削減） | なし |
| VPC Endpoints | secretsmanager, logs | なし |

> S3 と CloudFront は VPC 外のマネージドサービスのため、VPC 構成に変更なし。
> ECS タスクは Internet Gateway 経由で S3 にアクセス（Presigned URL 生成は API 経由）。

### 3.2 セキュリティグループ（変更なし）

v4 から全 SG を継続。S3 / CloudFront へのアクセスは SG ではなく IAM ポリシーで制御する。

## 4. 通信フロー

### 4.1 ファイルアップロードフロー（FR-15 / 新規）

```
User → ALB → ECS Task (FastAPI)
  1. POST /tasks/{task_id}/attachments のリクエストを受信
  2. task_id の存在確認（RDS）
  3. S3 Presigned PUT URL を生成（有効期限 300 秒���
  4. attachments テーブルに DB レコード INSERT
  5. 201 Created（upload_url 付き）を返す

User → S3（直接アップロード）
  6. Presigned PUT URL を使って S3 にファイルを直接 PUT
  7. S3 が Content-Type とサイズを検証
  8. アップロード成功（200 OK）
```

> **設計判断 - API サーバーを経由しない理由:**
> ファイルの本体データを ECS タスクが中継すると、メモリと帯域を消費する。
> Presigned URL を使うこと��、ECS タスクは URL 生成のみ担当し、実際のデータ転送は S3 が直接処理する。
> これにより ECS タスクのリソース使用量を抑え、Auto Scaling の観点でも有利。

### 4.2 ファイルダウンロードフロー（FR-17 / 新規）

```
User → ALB → ECS Task (FastAPI)
  1. GET /tasks/{task_id}/attachments/{id} のリクエストを受信
  2. attachments テーブルからメタデータ取得
  3. CloudFront URL を構築: https://{CLOUDFRONT_DOMAIN_NAME}/{s3_key}
  4. 200 OK（download_url 付き）を返す

User → CloudFront → S3（ダウンロード）
  5. CloudFront URL にアクセス
  6. CloudFront がキャッシュをチェック
     - キャッシュヒット: エッジから直接レスポンス
     - キャッシュミス: OAC で認証して S3 からフェッチ → キャッシュ → レスポンス
```

> **設計判断 - CloudFront 経由のダ���ンロード:**
> S3 直接アクセスを禁止（パブリックアクセスブロック + バケットポリシー）し、
> CloudFront OAC のみが S3 にアクセスできる構成にする。
> これにより CDN キャッシュによるレイテンシ削減 + S3 のセキュリティ保護を両立する。

### 4.3 ファイル削除フロー（FR-18 / 新規）

```
User ��� ALB → ECS Task (FastAPI)
  1. DELETE /tasks/{task_id}/attachments/{id} のリクエストを受信
  2. attachments テーブルからレコード取得（s3_key を確認）
  3. S3 から対象オブジェクトを削除（失敗時は警告ログのみ）
  4. attachments テーブルからレコード DELETE
  5. 204 No Content を返す
```

### 4.4 タスク削除時のカスケードフロー（FR-9 変更）

```
User → ALB → ECS Task (FastAPI)
  1. DELETE /tasks/{task_id} ���リクエスト��受信
  2. attachments テーブルから該当タスクの全添付ファイルの s3_key を��得
  3. 各 S3 オブジェクトを削除（失敗時は警告ログの��）
  4. tasks テーブルからレコード DELETE（ON DELETE CASCADE で attachments も自動削除）
  5. 204 No Content ��返す
```

### 4.5 既存フロー（変更なし）

- タスク作成フロー + SQS 通知（v4 FR-12）
- タスク完了フロー + EventBridge 通知（v4 FR-13）
- 定期クリーンアップフロー（v4 FR-14）
- Auto Scaling フロー（v3）

## 5. アプリケー���ョン構成

### 5.1 ファイル構成（v5 変更あり）

```
app/
├── main.py              [変更: attachments router を登録]
├── database.py          [変更なし]
├── models.py            [変更: Attachment モデル追加]
├── schemas.py           [変更: Attachment 関連スキーマ追加]
├── routers/
│   ├── tasks.py         [変更: 削除時に S3 オブジェクトもクリーンアップ]
│   └── attachments.py   [新規: 添付ファ���ル CRUD 4 エンドポイント]
├── services/
│   ├── events.py        [変更なし]
│   └── storage.py       [新規: S3 操作（Presigned URL 生成、オブジェクト削除）]
├── requirements.txt     [変更なし（boto3 は v4 で追加済み）]
├── Dockerfile           [変更なし]
├── alembic.ini          [��更なし]
└── alembic/
    └── versions/
        ├── 001_create_tasks_table.py    [既存]
        └── 002_create_attachments_table.py [新規]
```

### 5.2 DB スキーマ（attachments ��ーブル）

```
attachments
├── id              INTEGER  PRIMARY KEY, AUTOINCREMENT
├── task_id         INTEGER  NOT NULL, FOREIGN KEY → tasks(id) ON DELETE CASCADE
├── filename        VARCHAR(255)  NOT NULL
├── content_type    VARCHAR(100)  NOT NULL
��── s3_key          VARCHAR(512)  NOT NULL
├── file_size       BIGINT  NULLABLE
├── created_at      TIMESTAMP  NOT NULL, DEFAULT NOW()
└── updated_at      TIMESTAMP  NOT NULL, DEFAULT NOW(), ON UPDATE NOW()

INDEX: ix_attachments_task_id ON (task_id)
```

> **設計判断 - `ON DELETE CASCADE`:**
> タスクが削除されると、関連する attachments レコードも自動的に削除される。
> S3 オブジェクトの削除は API コードで明示的に行う（DB トリガーでは S3 操作ができないため���。

### 5.3 storage.py 設計

```python
# app/services/storage.py の責務
- S3 クライアント（boto3）の遅延初期化
- generate_upload_url(bucket, key, content_type, expires=300) → Presigned PUT URL を返す
- delete_object(bucket, key) → S3 オブジェクトを削除
- S3_BUCKET_NAME / CLOUDFRONT_DOMAIN_NAME は環境変数で設定

# 設計判断:
# - events.py と同じパターン（遅延クライアント初期化、環境変数依存、警告ログでの障害軽減）
# - Presigned URL は PUT のみ生成（ダウンロードは CloudFront 経由）
# - S3 未設定時は 503 Service Unavailable を返す
```

### 5.4 環境変数（ECS タスク定義への追加）

| ��数名 | 設定先 | 値の例 |
|--------|--------|--------|
| `S3_BUCKET_NAME` | ECS タスク定義 | `sample-cicd-dev-attachments` |
| `CLOUDFRONT_DOMAIN_NAME` | ECS ��スク定義 | `d1234abcdef.cloudfront.net` |
| `SQS_QUEUE_URL` | 既存 | （変更なし） |
| `EVENTBRIDGE_BUS_NAME` | 既存 | （変更なし） |
| `AWS_REGION` | 既存 | （変更なし） |

## 6. IAM 設計

### 6.1 ECS タスクロール（iam.tf 更新）

既存の ECS タスクロールに以下のポリシーを追加:

| 権限 | アクション | リソース |
|------|-----------|---------|
| S3 アップロード | `s3:PutObject` | `sample-cicd-dev-attachments/*` |
| S3 削除 | `s3:DeleteObject` | `sample-cicd-dev-attachments/*` |

> Presigned URL の生成には `s3:PutObject` 権限が必要（URL の署名に使われるため）。
> `s3:GetObject` は不要（ダウンロードは CloudFront OAC 経由）���

### 6.2 CloudFront OAC → S3 バケットポリシー

```json
{
  "Effect": "Allow",
  "Principal": {"Service": "cloudfront.amazonaws.com"},
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::sample-cicd-dev-attachments/*",
  "Condition": {
    "StringEquals": {
      "AWS:SourceArn": "arn:aws:cloudfront::ACCOUNT_ID:distribution/DISTRIBUTION_ID"
    }
  }
}
```

> **設計判断 - OAC（Origin Access Control）を使う理由:**
> OAI（Origin Access Identity）は非推奨。OAC は AWS が推奨する新しい方式で、
> S3 SSE-KMS 暗号化への対応やより細かい IAM ポリシー制御が可能。

### 6.3 既存 IAM ロール（変更なし）

Lambda 実行ロール 3 つ、Scheduler ロールは v4 から変���なし。

## 7. Terraform Workspace 設計

### 7.1 Workspace 構成

| 項目 | 内容 |
|------|------|
| Workspace 名 | `dev`（開発）、`prod`（本番） |
| 命名規則 | `${var.project_name}-${terraform.workspace}-{リソース名}` |
| 状態管理 | Workspace ごとに独立した tfstate（`terraform.tfstate.d/{env}/`） |
| デプロイ対象 | `dev` のみ実デプロイ。`prod` は tfvars のみ |

### 7.2 locals ブロック

```hcl
locals {
  env    = terraform.workspace
  prefix = "${var.project_name}-${local.env}"
}
```

全リソースの `name` / `tags` で `${var.project_name}` → `${local.prefix}` に置換する。

### 7.3 環境別パラメータ差分

| パラメータ | dev | prod |
|-----------|-----|------|
| ECS CPU / Memory | 256 / 512 | 512 / 1024 |
| ECS タスク数（desired / min / max） | 1 / 1 / 2 | 2 / 2 / 4 |
| RDS インスタンスクラス | db.t3.micro | db.t3.small |
| RDS Multi-AZ | false | true |
| CloudFront Price Class | PriceClass_100 | PriceClass_200 |
| ログ保持期間（日） | 7 | 30 |
| Lambda ログ保持期間（日） | 7 | 30 |

### 7.4 移行戦略

v4 は `default` Workspace で管理されていたため、リソース名に環境名が含まれていない。
v5 では全リソース名が変更されるため、v4 リソースを `terraform destroy` 後に v5 で再デプロイする。

```bash
# v4 クリーンアップ
cd infra && terraform destroy

# v5 デプロイ
terraform workspace new dev
terraform workspace select dev
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```
