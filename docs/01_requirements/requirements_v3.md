# 要件定義書 (v3)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-03 |
| バージョン | 3.0 |
| 前バージョン | [requirements_v2.md](requirements_v2.md) (v2.0) |

## 変更概要

v2（タスク管理 API + RDS PostgreSQL）に以下を追加する:
- ECS Service Auto Scaling（CPU 負荷ベースのタスク数自動調整）
- RDS Multi-AZ 構成（DB の高可用性）
- HTTPS 化の Terraform コード整備（ACM + Route53 + ALB HTTPS リスナー）
  - ※ ドメイン取得が前提のため、**コードのみ成果物とし実デプロイは行わない**

## 1. プロジェクト概要

### 1.1 目的

v2 で構築したタスク管理 API に「スケーラビリティ」と「高可用性」を追加する。
負荷変動に応じて自動でリソースを増減させる仕組みと、
DB の障害に対して自動フェイルオーバーする構成を学習する。

### 1.2 学習目標

| # | 学習テーマ | 内容 | デプロイ |
|---|-----------|------|:---:|
| 1 | Application Auto Scaling | ECS サービス以外のリソースもスケールさせる AWS サービス | ✅ |
| 2 | Target Tracking Scaling Policy | 目標 CPU 使用率を維持するようにタスク数を自動調整する | ✅ |
| 3 | Scale-in / Scale-out Cooldown | スケールイン・スケールアウトのクールダウン設定 | ✅ |
| 4 | CloudWatch Alarms | スケーリングトリガーとなるアラームの仕組みを理解する | ✅ |
| 5 | RDS Multi-AZ | 複数の AZ に同期レプリケーションし、障害時に自動フェイルオーバーする | ✅ |
| 6 | ACM | SSL/TLS 証明書の無料発行・自動更新の仕組みを理解する | コードのみ |
| 7 | Route53 | DNS レコード管理とドメイン設定の仕組みを理解する | コードのみ |
| 8 | HTTPS 化 | ALB への HTTPS リスナー追加と HTTP リダイレクト設定 | コードのみ |

### 1.3 スコープ

**スコープ内（実デプロイあり）:**
- ECS Service Auto Scaling の実装
  - Application Auto Scaling リソース登録
  - CPU 使用率ベースのターゲット追跡スケーリングポリシー
  - 最小 1 タスク / 最大 3 タスク
- RDS Multi-AZ への変更

**スコープ内（コードのみ、未デプロイ）:**
- ACM パブリック証明書の Terraform コード
- Route53 ホストゾーン・DNS レコードの Terraform コード
- ALB HTTPS リスナー（ポート 443）の Terraform コード
- HTTP → HTTPS リダイレクト（ポート 80）の Terraform コード

**スコープ外（v2 から変更なし）:**
- ユーザー認証・認可
- CloudFront / CDN
- WAF (Web Application Firewall)
- マルチ環境（staging / production）の分離
- NAT Gateway
- カスタムドメインの取得・実際の DNS 設定

## 2. 機能要件

### 既存（v2 から継続）

| ID | 概要 | 変更 |
|----|------|------|
| FR-1 | Hello World API (`GET /`) | なし |
| FR-2 | ヘルスチェック (`GET /health`) | なし |
| FR-3 | CI パイプライン | なし |
| FR-4 | CD パイプライン | なし |
| FR-5 | タスク一覧取得 (`GET /tasks`) | なし |
| FR-6 | タスク作成 (`POST /tasks`) | なし |
| FR-7 | タスク個別取得 (`GET /tasks/{id}`) | なし |
| FR-8 | タスク更新 (`PUT /tasks/{id}`) | なし |
| FR-9 | タスク削除 (`DELETE /tasks/{id}`) | なし |
| FR-10 | データベース永続化 | RDS Multi-AZ に変更 |

### 新規

#### FR-11: ECS Auto Scaling

| 項目 | 内容 |
|------|------|
| ID | FR-11 |
| 概要 | CPU 使用率に応じて ECS タスク数を自動増減する |
| スケーリング条件 | CPU 使用率 70% をターゲットに自動調整 |
| 最小タスク数 | 1 |
| 最大タスク数 | 3 |
| スケールアウト後クールダウン | 60 秒 |
| スケールイン後クールダウン | 300 秒 |
| 対応要件 | ECS タスクが増減しても API のエンドポイントに変化がないこと（ALB が吸収） |

#### FR-12: RDS Multi-AZ（v2 の FR-10 を更新）

| 項目 | 内容 |
|------|------|
| ID | FR-12 |
| 概要 | RDS を Multi-AZ 構成に変更し、プライマリ障害時に自動フェイルオーバーする |
| フェイルオーバー時間 | 約 60〜120 秒（AWS 公式値） |
| データロス | 同期レプリケーションのためゼロ |
| アプリへの影響 | DB 接続が一時切断されるが、SQLAlchemy の再接続で自動回復する |
| DB エンジン | PostgreSQL 15（変更なし） |

#### FR-13: HTTPS 化（コードのみ）

| 項目 | 内容 |
|------|------|
| ID | FR-13 |
| 概要 | ACM + Route53 + ALB HTTPS リスナーの Terraform コードを整備する |
| 実デプロイ | しない（カスタムドメイン取得後に `terraform apply` できる状態にする） |
| 証明書 | ACM パブリック証明書（DNS 検証方式） |
| DNS | Route53 ホストゾーン + A レコード（ALB へのエイリアス） |
| ALB 変更 | ポート 443 リスナー追加 / ポート 80 リスナーを HTTP → HTTPS リダイレクトに変更 |

## 3. 非機能要件

### 既存（v2 から継続）

| ID | 概要 | 変更 |
|----|------|------|
| NFR-1 | 可用性 | RDS Multi-AZ により向上 |
| NFR-3 | パフォーマンス | Auto Scaling により高負荷時も維持 |
| NFR-4 | 運用性 | なし |

### 変更

#### NFR-2: セキュリティ（更新）

| 項目 | 内容 |
|------|------|
| ID | NFR-2 |
| IAM | ECS タスク実行ロールに Application Auto Scaling 向けの権限なし（Auto Scaling は別ロール使用） |
| HTTPS | コードのみ整備（未デプロイ） |
| その他 | v2 から変更なし |

#### NFR-5: コスト（更新）

| 項目 | 内容 |
|------|------|
| ID | NFR-5 |
| Fargate | 0.25 vCPU / 512 MB × 最小 1 タスク（Auto Scaling で最大 3 タスクに増加） |
| RDS | db.t3.micro / **Multi-AZ** / 20 GB gp2（約 **$30**/月 ← v2 の $15 から倍増） |
| Secrets Manager | 1 シークレット（約 $0.40/月、変更なし） |
| 概算合計 | 約 **$60**/月（v2 の $45 から +$15） |
| 注意 | **RDS Multi-AZ はコストが倍になるため、学習完了後は必ずリソースを削除すること** |

#### NFR-6: スケーラビリティ（新規）

| 項目 | 内容 |
|------|------|
| ID | NFR-6 |
| ECS | 最小 1 タスク〜最大 3 タスクに自動調整（CPU 70% をターゲット） |
| DB | Multi-AZ により AZ 障害時でも継続稼働 |
| ALB | 複数タスクへのリクエスト分散（変更なし） |

## 4. AWS 構成

| サービス | 用途 | v2 | v3 |
|----------|------|:--:|:--:|
| ECR | Docker イメージレジストリ | o | o |
| ECS (Fargate) | コンテナ実行環境 | o | o |
| ALB | ロードバランサー | o | o |
| VPC | ネットワーク | o | o |
| IAM | ロールとポリシー | o | o |
| CloudWatch Logs | コンテナログ | o | o |
| RDS (PostgreSQL) | データベース Single-AZ | o | → |
| RDS (PostgreSQL) | データベース Multi-AZ | - | **o** |
| Secrets Manager | クレデンシャル管理 | o | o |
| Application Auto Scaling | ECS タスク数自動調整 | - | **o** |
| CloudWatch Alarms | Auto Scaling トリガー | - | **o** |
| ACM | SSL/TLS 証明書 | - | コードのみ |
| Route53 | DNS 管理 | - | コードのみ |

リージョン: **ap-northeast-1**（東京）

## 5. 技術スタック

| カテゴリ | 技術 | v2 | v3 |
|----------|------|:--:|:--:|
| 言語 | Python 3.12 | o | o |
| フレームワーク | FastAPI | o | o |
| ORM | SQLAlchemy | o | o |
| マイグレーション | Alembic | o | o |
| DB ドライバ | psycopg2-binary | o | o |
| IaC | Terraform | o | o |
| CI/CD | GitHub Actions | o | o |
| コンテナ | Docker | o | o |
| Lint | ruff | o | o |
| テスト | pytest | o | o |

アプリケーションコードの変更はなし。Terraform のみ変更。

## 6. 前提条件・制約

### 前提条件

- v2 の全成果物が完成済みであること
- AWS アカウントが利用可能であること
- GitHub リポジトリが利用可能であること

### 制約

- AWS リージョンは ap-northeast-1（東京）固定
- 環境は本番（production）のみ
- HTTPS は実デプロイしない（コードのみ）
- RDS Multi-AZ のフェイルオーバーは動作確認のみ（実際の障害テストは範囲外）
- NAT Gateway は使用しない（コスト削減、v2 から変更なし）
- Auto Scaling の負荷テストは簡易的なもの（Apache Bench 等）

## 7. 用語集（v3 追加分）

| 用語 | 説明 |
|------|------|
| Application Auto Scaling | EC2 以外のリソース（ECS, DynamoDB, Aurora 等）のスケールを管理する AWS サービス |
| Target Tracking Scaling Policy | 指定したメトリクスの目標値に向かってリソースを増減させるスケーリングポリシー |
| Scale-out | リソースを増やすこと（ECS タスクを 1 → 2 に増やすなど） |
| Scale-in | リソースを減らすこと（ECS タスクを 2 → 1 に減らすなど） |
| Cooldown | スケーリングアクション後、次のスケーリングを行うまでの待機時間 |
| CloudWatch Alarm | CloudWatch メトリクスが閾値を超えたときにアクションを実行する仕組み |
| Multi-AZ | 複数の Availability Zone（データセンター）に同期レプリケーション。プライマリ障害時に自動フェイルオーバー |
| フェイルオーバー | プライマリ DB が障害になった際、スタンバイ DB に自動切り替えすること |
| ACM | AWS Certificate Manager。SSL/TLS 証明書を無料で発行・自動更新するサービス |
| Route53 | AWS の DNS サービス。ドメイン登録・DNS レコード管理 |
