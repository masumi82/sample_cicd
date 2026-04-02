# 要件定義書

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-02 |
| バージョン | 1.0 |

## 1. プロジェクト概要

### 1.1 目的

GitHub Actions と AWS ECS (Fargate) を用いた CI/CD パイプラインの構築を通じて、
コンテナベースのサーバーレスデプロイの一連の流れを学習する。

### 1.2 背景

- GitLab Runner の経験はあるが、GitHub Actions は未経験
- Docker は `docker run` レベルで、Dockerfile の作成は学習対象
- Terraform は初学者
- AWS アカウントはあるが CLI は未設定

### 1.3 スコープ

**スコープ内:**
- FastAPI による最小限の Hello World API の開発
- Docker イメージのビルドと ECR へのプッシュ
- Terraform による AWS インフラのプロビジョニング
- GitHub Actions による CI/CD パイプラインの構築
- ECS (Fargate) へのデプロイ

**スコープ外:**
- データベース連携
- ユーザー認証・認可
- カスタムドメイン・SSL 証明書（ACM）
- 複数環境（staging / production）の分離
- Auto Scaling の設定

## 2. 機能要件

### FR-1: Hello World API

| 項目 | 内容 |
|------|------|
| ID | FR-1 |
| 概要 | ルートパスで JSON レスポンスを返す API |
| エンドポイント | `GET /` |
| レスポンス | `{"message": "Hello, World!"}` |
| ステータスコード | 200 OK |

### FR-2: ヘルスチェックエンドポイント

| 項目 | 内容 |
|------|------|
| ID | FR-2 |
| 概要 | ALB のターゲットグループヘルスチェック用エンドポイント |
| エンドポイント | `GET /health` |
| レスポンス | `{"status": "healthy"}` |
| ステータスコード | 200 OK |

### FR-3: CI パイプライン

| 項目 | 内容 |
|------|------|
| ID | FR-3 |
| 概要 | コード品質チェックとテストの自動実行 |
| トリガー | `main` ブランチへの push および Pull Request |
| ステップ | 1. コードチェックアウト |
| | 2. Python セットアップ |
| | 3. 依存パッケージインストール |
| | 4. Lint（ruff） |
| | 5. テスト実行（pytest） |
| | 6. Docker イメージビルド |

### FR-4: CD パイプライン

| 項目 | 内容 |
|------|------|
| ID | FR-4 |
| 概要 | コンテナイメージのプッシュと ECS へのデプロイ |
| トリガー | `main` ブランチへの push（CI 成功後） |
| ステップ | 1. AWS 認証情報の設定 |
| | 2. ECR へのログイン |
| | 3. Docker イメージのタグ付けとプッシュ |
| | 4. ECS タスク定義の更新 |
| | 5. ECS サービスの更新（ローリングデプロイ） |

## 3. 非機能要件

### NFR-1: 可用性

| 項目 | 内容 |
|------|------|
| ID | NFR-1 |
| Fargate タスク数 | 1（学習用のため最小構成） |
| ヘルスチェック | ALB が `/health` を 30 秒間隔でチェック |
| デプロイ方式 | ローリングデプロイ（minimumHealthyPercent: 100） |

### NFR-2: セキュリティ

| 項目 | 内容 |
|------|------|
| ID | NFR-2 |
| IAM | ECS タスクに最小権限の IAM ロールを付与（アクセスキー不使用） |
| コンテナ | 非 root ユーザーで実行 |
| シークレット | AWS 認証情報は GitHub Actions Secrets で管理 |
| ネットワーク | ALB は HTTP (80) のみ公開、ECS タスクはプライベートサブネット |
| イメージスキャン | ECR のイメージスキャンを有効化 |

### NFR-3: パフォーマンス

| 項目 | 内容 |
|------|------|
| ID | NFR-3 |
| レスポンスタイム | `GET /` および `GET /health` で 500ms 以内 |
| コンテナリソース | CPU: 256 (0.25 vCPU), Memory: 512 MB |

### NFR-4: 運用性

| 項目 | 内容 |
|------|------|
| ID | NFR-4 |
| ログ | CloudWatch Logs にコンテナログを出力 |
| イメージタグ | Git コミット SHA をタグとして使用 |
| 監視 | ECS サービスのヘルスステータスを ALB ヘルスチェックで確認 |

### NFR-5: コスト

| 項目 | 内容 |
|------|------|
| ID | NFR-5 |
| 方針 | 学習用のため最小構成で運用 |
| Fargate | 0.25 vCPU / 512 MB の最小スペック |
| NAT Gateway | コスト削減のため、ECS タスクはパブリックサブネットに配置も検討 |
| 注意 | 学習完了後はリソースを確実に削除すること |

## 4. AWS 構成

| サービス | 用途 |
|----------|------|
| ECR | Docker イメージレジストリ |
| ECS (Fargate) | コンテナ実行環境 |
| ALB | ロードバランサー / HTTP エンドポイント |
| VPC | ネットワーク（パブリック/プライベートサブネット） |
| IAM | ロールとポリシー |
| CloudWatch Logs | コンテナログ |

リージョン: **ap-northeast-1**（東京）

## 5. 技術スタック

| カテゴリ | 技術 |
|----------|------|
| 言語 | Python 3.12 |
| フレームワーク | FastAPI |
| IaC | Terraform |
| CI/CD | GitHub Actions |
| コンテナ | Docker |
| Lint | ruff |
| テスト | pytest |

## 6. 前提条件・制約

### 前提条件

- AWS アカウントが利用可能であること
- GitHub リポジトリが利用可能であること
- ローカル環境に Docker がインストール済みであること

### 制約

- AWS リージョンは ap-northeast-1（東京）固定
- 環境は本番（production）のみ（staging 環境は対象外）
- HTTPS 対応はスコープ外（ALB は HTTP:80 のみ）
- データベースは使用しない

## 7. 用語集

| 用語 | 説明 |
|------|------|
| ECS | Elastic Container Service。コンテナオーケストレーションサービス |
| Fargate | サーバーレスのコンテナ実行環境。EC2 インスタンスの管理が不要 |
| ECR | Elastic Container Registry。Docker イメージの保存先 |
| ALB | Application Load Balancer。HTTP リクエストの負荷分散 |
| CI | Continuous Integration。コードの自動テスト・ビルド |
| CD | Continuous Deployment。自動デプロイ |
| IaC | Infrastructure as Code。インフラをコードで管理する手法 |
| Terraform | HashiCorp 製の IaC ツール |
| GitHub Actions | GitHub のワークフロー自動化サービス |
| Fargate タスク | ECS 上で実行されるコンテナの単位 |
