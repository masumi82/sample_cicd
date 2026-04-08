# 要件定義書 (v8)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-07 |
| バージョン | 8.0 |
| 前バージョン | [requirements_v7.md](requirements_v7.md) (v7.0) |

## 変更概要

v7（Security + Authentication）に以下を追加する:

- **カスタムドメイン + HTTPS**: Route 53 で取得したドメイン `sample-cicd.click` を使い、ACM 証明書による HTTPS 化を実現。CloudFront にカスタムドメインを適用
- **サブドメイン設計**: `sample-cicd.click`（Web UI）/ `api.sample-cicd.click`（API）の構成、dev/prod 環境分離
- **Terraform Remote State**: S3 + DynamoDB による state 管理。ローカル state からの移行で運用安全性を向上

## 1. プロジェクト概要

### 1.1 目的

v7 まではローカル state + CloudFront デフォルトドメイン（`dXXXXXXXXXXXXX.cloudfront.net`）で運用してきたが、以下の課題がある:

1. **カスタムドメインなし**: ユーザーに見せられる URL ではない。HTTPS は CloudFront デフォルトで提供されるが、ブランディング・可読性に欠ける
2. **Terraform state がローカル**: state ファイル紛失リスク、チーム開発でのロック競合、CI/CD からの `terraform apply` が困難

v8 ではこれらを解決し、本番運用に近いインフラ基盤を完成させる。

### 1.2 学習目標

| # | 学習テーマ | 内容 | デプロイ |
|---|-----------|------|:---:|
| 1 | Route 53 | Hosted Zone、DNS レコード管理（A / CNAME / Alias） | ✅ |
| 2 | ACM 証明書 | パブリック証明書の発行、DNS 検証、リージョン制約 | ✅ |
| 3 | CloudFront カスタムドメイン | 代替ドメイン名（Alternate Domain Names）、SSL 証明書の紐付け | ✅ |
| 4 | サブドメイン設計 | 環境別サブドメイン（dev / prod）、パスベースルーティング vs サブドメイン分割 | ✅ |
| 5 | Terraform Remote State | S3 backend + DynamoDB ロック、bootstrap 手順、state 移行 | ✅ |
| 6 | Terraform Backend 設定 | `backend "s3"` ブロック、`-backend-config` オプション | ✅ |

### 1.3 スコープ

**スコープ内:**

- Route 53 Hosted Zone でのDNS 管理（`sample-cicd.click`）
- ACM 証明書の発行（`us-east-1` for CloudFront）
  - `sample-cicd.click` + `*.sample-cicd.click` のワイルドカード証明書
- CloudFront（Web UI）にカスタムドメイン適用
  - prod: `sample-cicd.click`
  - dev: `dev.sample-cicd.click`
- CloudFront（API プロキシ）のパスベースルーティング継続（v6 方式）
  - `/api/*` → ALB（既存の CloudFront behavior を維持）
- Route 53 DNS レコード作成（A レコード Alias → CloudFront）
- v3 で準備済みの `infra/https.tf` の再利用・拡張
- Terraform Remote State 導入
  - S3 バケット（state 保存）+ DynamoDB テーブル（ロック）の作成
  - bootstrap 用の別 Terraform プロジェクト or 手動作成手順
  - 既存ローカル state からの移行手順
- `dev.tfvars` / `prod.tfvars` のドメイン設定更新
- CI/CD パイプラインの更新（Remote State 対応、CORS オリジン更新）
- フロントエンド `config.js` の API ベース URL 更新

**スコープ外:**

- ALB への直接 HTTPS リスナー追加（CloudFront 経由のため不要。v3 `https.tf` の ALB リスナー部分は使用しない）
- 独立した API 用 CloudFront ディストリビューション（既存のパスベースルーティングを継続）
- DNSSEC
- Route 53 ヘルスチェック（CloudFront + ALB のヘルスチェックで十分）
- Route 53 フェイルオーバールーティング
- マルチリージョンデプロイ
- `prod` 環境への実デプロイ（tfvars ファイルの更新のみ）

## 2. 機能要件

### 既存（v7 から継続）

| ID | 概要 | 変更 |
|----|------|------|
| FR-1 | Hello World API (`GET /`) | なし |
| FR-2 | ヘルスチェック (`GET /health`) | なし |
| FR-3 | CI パイプライン | なし |
| FR-4 | CD パイプライン | Remote State 対応、CORS オリジン更新 |
| FR-5〜FR-9 | タスク CRUD API | なし |
| FR-10 | データベース永続化 | なし |
| FR-11 | ECS Auto Scaling | なし |
| FR-12〜FR-14 | イベント駆動処理 | なし |
| FR-15〜FR-18 | 添付ファイル CRUD API | なし |
| FR-19 | マルチ環境管理 | なし |
| FR-20〜FR-24 | Observability | なし |
| FR-25〜FR-29 | Web UI | API ベース URL をカスタムドメインに更新 |
| FR-30 | CORS ミドルウェア | `CORS_ALLOWED_ORIGINS` をカスタムドメインに更新 |
| FR-31 | フロントエンド CI/CD | `config.js` にカスタムドメイン設定注入 |
| FR-32〜FR-38 | Cognito 認証 | なし |
| FR-39〜FR-40 | WAF | なし |
| FR-41 | HTTPS + カスタムドメイン（v7 オプション） | **v8 で正式実装に昇格** |

### 新規

#### FR-42: Route 53 Hosted Zone

| 項目 | 内容 |
|------|------|
| ID | FR-42 |
| 概要 | `sample-cicd.click` の DNS を Route 53 Hosted Zone で管理する |
| ドメイン | `sample-cicd.click`（Route 53 で購入済み） |
| 管理対象 | A レコード（CloudFront Alias）、ACM DNS 検証用 CNAME |
| Terraform リソース | `aws_route53_zone`（既に `https.tf` に定義済み。拡張して使用） |
| 備考 | Route 53 でドメイン購入時に Hosted Zone は自動作成される。Terraform では `data` ソースで参照するか、`import` で取り込む |

#### FR-43: ACM 証明書

| 項目 | 内容 |
|------|------|
| ID | FR-43 |
| 概要 | CloudFront 用の SSL/TLS 証明書を ACM で発行する |
| リージョン | `us-east-1`（CloudFront が us-east-1 の証明書のみ受け付ける） |
| ドメイン名 | `sample-cicd.click` |
| SAN (Subject Alternative Name) | `*.sample-cicd.click`（ワイルドカード。dev サブドメイン等に対応） |
| 検証方式 | DNS 検証（Route 53 に CNAME レコードを自動作成） |
| 既存コード | `infra/https.tf` の `aws_acm_certificate.app` を拡張 |
| Terraform リソース | `aws_acm_certificate`, `aws_route53_record` (DNS 検証), `aws_acm_certificate_validation` |
| provider | `us-east-1` 用の alias provider を追加（`provider = aws.us_east_1`） |

#### FR-44: CloudFront カスタムドメイン

| 項目 | 内容 |
|------|------|
| ID | FR-44 |
| 概要 | CloudFront ディストリビューションにカスタムドメインを適用する |
| Web UI CloudFront | `aliases = ["sample-cicd.click"]`（prod） / `["dev.sample-cicd.click"]`（dev） |
| SSL 証明書 | ACM 証明書（FR-43）を `viewer_certificate` に設定 |
| 最低 SSL プロトコル | TLSv1.2_2021 |
| API プロキシ | 既存のパスベースルーティング（`/api/*` → ALB）を維持。同一 CloudFront 内 |
| DNS レコード | Route 53 A レコード（Alias → CloudFront）を作成 |
| 既存コード | `infra/webui.tf` の CloudFront リソースを更新 |

#### FR-45: サブドメイン設計

| 項目 | 内容 |
|------|------|
| ID | FR-45 |
| 概要 | 環境ごとにサブドメインを分離する |
| prod | `sample-cicd.click` → CloudFront（Web UI + API パスベースルーティング） |
| dev | `dev.sample-cicd.click` → CloudFront（Web UI + API パスベースルーティング） |
| 添付ファイル CloudFront | 既存のまま（CloudFront デフォルトドメイン）。カスタムドメインはオプション |
| CORS 設定 | `cors_allowed_origins` を `["https://sample-cicd.click"]`（prod）/ `["https://dev.sample-cicd.click"]`（dev）に更新 |

#### FR-46: Terraform Remote State

| 項目 | 内容 |
|------|------|
| ID | FR-46 |
| 概要 | Terraform state を S3 + DynamoDB で管理する |
| S3 バケット | `sample-cicd-terraform-state`（バージョニング有効、暗号化有効） |
| DynamoDB テーブル | `sample-cicd-terraform-lock`（LockID パーティションキー） |
| Backend 設定 | `backend "s3"` ブロックを `infra/main.tf` に追加 |
| 環境分離 | Terraform Workspace（`dev` / `prod`）で state を自動分離（`key = "sample-cicd/terraform.tfstate"` + workspace prefix） |
| Bootstrap | `infra/bootstrap/` ディレクトリに state 管理用リソースの Terraform コードを作成。初回のみ `terraform apply` |
| 移行手順 | `terraform init -migrate-state` で既存ローカル state を S3 に移行 |
| CI/CD | GitHub Actions から `terraform plan` / `apply` を実行可能にする基盤（実際の CD 統合は将来検討） |

#### FR-47: v3 既存コード（`https.tf`）との関係

| 項目 | 内容 |
|------|------|
| ID | FR-47 |
| 概要 | v3 で準備した `infra/https.tf` を評価し、再利用 / 書き直しを判断する |
| 再利用する部分 | ACM 証明書リソース（`aws_acm_certificate.app`）の基本構造、DNS 検証の仕組み |
| 書き直す部分 | (1) ACM を `us-east-1` provider に変更（現在はデフォルトリージョン）、(2) `domain_name` に SAN（ワイルドカード）追加、(3) Route 53 zone は `data` ソースに変更（購入時に自動作成されるため）、(4) A レコードのエイリアス先を ALB → CloudFront に変更、(5) ALB HTTPS リスナー部分は削除（CloudFront 経由のため不要） |
| 変数統合 | `enable_https` + `enable_custom_domain` を `enable_custom_domain` に統一。`domain_name` + `custom_domain_name` も統一 |

## 3. 非機能要件

### 既存（v7 から継続）

| ID | 概要 | 変更 |
|----|------|------|
| NFR-1 | 可用性 | なし |
| NFR-2 | セキュリティ | HTTPS カスタムドメインで通信セキュリティ向上 |
| NFR-3 | パフォーマンス | なし |
| NFR-4 | 運用性 | Remote State で運用安全性向上（下記参照） |
| NFR-5 | コスト | 下記参照 |
| NFR-6 | スケーラビリティ | なし |
| NFR-7 | 疎結合性 | なし |
| NFR-8 | コンテンツ配信 | カスタムドメインで配信 |
| NFR-9 | 可観測性 | なし |
| NFR-10 | 認証・認可 | なし |

### 変更・追加

#### NFR-4: 運用性（更新）

| 項目 | 内容 |
|------|------|
| ID | NFR-4 |
| Terraform State | S3 に保存。バージョニング有効で誤操作時のリカバリが可能 |
| State ロック | DynamoDB によるロック。複数人 / CI からの同時実行を防止 |
| State 暗号化 | S3 サーバーサイド暗号化（SSE-S3）で state ファイルを暗号化 |
| Bootstrap | state 管理用リソースは独立した Terraform で管理。鶏と卵の問題を回避 |

#### NFR-5: コスト（更新）

| 項目 | 内容 |
|------|------|
| ID | NFR-5 |
| Route 53 Hosted Zone | $0.50/月 |
| Route 53 クエリ | $0.40/100 万クエリ → 学習用は実質 **$0** |
| ドメイン (`sample-cicd.click`) | $3.00/年（≒ $0.25/月） |
| ACM 証明書 | **$0**（パブリック証明書は無料、自動更新） |
| S3 (Remote State) | **$0**（数 KB の state ファイル） |
| DynamoDB (State Lock) | **$0**（オンデマンドモード、学習用は無料枠内） |
| v8 追加分合計 | 約 **$0.75/月**（+ ドメイン $3/年） |
| 全体合計概算 | 約 **$98〜99/月**（v7 $97〜98 + v8 $0.75） |

#### NFR-11: DNS・ドメイン管理（新規）

| 項目 | 内容 |
|------|------|
| ID | NFR-11 |
| ドメイン | `sample-cicd.click`（Route 53 Registrar で購入） |
| TLD | `.click`（$3/年） |
| DNS 管理 | Route 53 Hosted Zone で一元管理 |
| 証明書更新 | ACM が自動更新（DNS 検証方式のため、Route 53 レコードが存在する限り自動） |
| TTL | A レコード: 300 秒（Alias のため AWS 管理）、その他: 300 秒 |

## 4. AWS 構成

| サービス | 用途 | v7 | v8 |
|----------|------|:--:|:--:|
| ECR | Docker イメージレジストリ | o | o |
| ECS (Fargate) | コンテナ実行環境 | o | o |
| ALB | ロードバランサー | o | o |
| VPC | ネットワーク | o | o |
| IAM | ロールとポリシー | o | o |
| CloudWatch Logs | ログ | o | o |
| CloudWatch Dashboard | メトリクス統合表示 | o | o |
| CloudWatch Alarms | 障害検知 | o | o |
| RDS (PostgreSQL) | データベース | o | o |
| Secrets Manager | クレデンシャル管理 | o | o |
| Auto Scaling | ECS タスク数自動調整 | o | o |
| SQS + DLQ | イベントキュー | o | o |
| Lambda | イベントハンドラ x 3 | o | o |
| EventBridge | イベントバス + Scheduler | o | o |
| VPC エンドポイント | Lambda 用 | o | o |
| S3 (attachments) | 添付ファイルストレージ | o | o |
| S3 (webui) | Web UI 静的ホスティング | o | o |
| CloudFront (attachments) | 添付ファイル CDN | o | o |
| CloudFront (webui) | Web UI CDN + API プロキシ | o | o（**カスタムドメイン適用**） |
| SNS | アラーム通知 | o | o |
| X-Ray | 分散トレーシング | o | o |
| Cognito | ユーザー認証 | o | o |
| WAF v2 | Web Application Firewall | o | o |
| ACM | SSL/TLS 証明書 | optional | **o（必須化）** |
| Route 53 | DNS 管理 | optional | **o（必須化）** |
| **S3 (terraform-state)** | **Terraform state 保存** | - | **o** |
| **DynamoDB (terraform-lock)** | **Terraform state ロック** | - | **o** |

リージョン: **ap-northeast-1**（東京）
※ ACM 証明書（CloudFront 用）は **us-east-1** に作成
※ WAF WebACL（CloudFront 用）は引き続き **us-east-1** に作成

## 5. 技術スタック

| カテゴリ | 技術 | v7 | v8 |
|----------|------|:--:|:--:|
| 言語 (Backend) | Python 3.12 | o | o |
| フレームワーク | FastAPI | o | o |
| ORM | SQLAlchemy | o | o |
| AWS SDK (Python) | boto3 | o | o |
| JWT ライブラリ | python-jose[cryptography] | o | o |
| トレーシング | aws-xray-sdk | o | o |
| IaC | Terraform | o | o（**Remote State、provider alias 追加**） |
| CI/CD | GitHub Actions | o | o |
| Lint (Python) | ruff | o | o |
| テスト | pytest + moto | o | o |
| 言語 (Frontend) | JavaScript (JSX) | o | o |
| フレームワーク (Frontend) | React 19 | o | o |
| ビルドツール | Vite | o | o |
| 認証 SDK | amazon-cognito-identity-js | o | o |

## 6. 環境変数

### 追加・変更

| Variable | Where | Required | Description |
|----------|-------|----------|-------------|
| `CORS_ALLOWED_ORIGINS` | ECS | Optional | `https://sample-cicd.click`（prod）/ `https://dev.sample-cicd.click`（dev）に更新 |

※ v8 ではアプリケーションコードへの環境変数追加はなし。変更は Terraform 変数と `config.js` の注入値のみ。

### Terraform 変数の変更

| Variable | 変更内容 |
|----------|---------|
| `enable_https` | **廃止** → `enable_custom_domain` に統一 |
| `domain_name` | **廃止** → `custom_domain_name` に統一 |
| `enable_custom_domain` | デフォルト `true` に変更（v8 で正式機能化） |
| `custom_domain_name` | `sample-cicd.click` を設定 |
| `hosted_zone_id` | Route 53 Hosted Zone ID を設定 |

## 7. 実装方針

### 7.1 v3 既存コード（`infra/https.tf`）の扱い

| 既存リソース | 方針 | 理由 |
|-------------|------|------|
| `aws_acm_certificate.app` | **拡張して再利用** | 基本構造は同じ。provider を `us-east-1` に変更、SAN にワイルドカード追加 |
| `aws_route53_zone.app` | **`data` ソースに変更** | Route 53 でドメイン購入時に Hosted Zone が自動作成されるため、新規作成ではなく参照 |
| `aws_route53_record.acm_validation` | **再利用** | DNS 検証の仕組みは同じ |
| `aws_acm_certificate_validation.app` | **再利用** | 変更なし |
| `aws_route53_record.app` | **書き直し** | エイリアス先を ALB → CloudFront に変更。dev サブドメイン用レコードも追加 |
| `aws_lb_listener.https` | **削除** | CloudFront → ALB は HTTP で十分（CloudFront がHTTPS を終端） |

### 7.2 Terraform ファイル構成

```
infra/
  main.tf          # backend "s3" ブロック追加
  https.tf         # → custom_domain.tf にリネーム推奨。ACM + Route 53 + CloudFront 更新
  providers.tf     # aws.us_east_1 alias provider 追加（既存の waf.tf から分離検討）
  ...
  bootstrap/
    main.tf        # S3 バケット + DynamoDB テーブル（state 管理用）
    outputs.tf     # バケット名、テーブル名を出力
```

### 7.3 Bootstrap 手順（Remote State）

1. `infra/bootstrap/` で `terraform init && terraform apply` → S3 バケット + DynamoDB テーブル作成
2. `infra/main.tf` に `backend "s3"` ブロックを追加
3. `terraform init -migrate-state` で既存ローカル state を S3 に移行
4. ローカルの `terraform.tfstate` を `.gitignore` に追加（state は S3 で管理）
5. GitHub Actions に S3 / DynamoDB へのアクセス権限を付与（将来の CI/CD 統合用）

### 7.4 CloudFront 更新イメージ

```hcl
# infra/webui.tf（変更部分のみ）
resource "aws_cloudfront_distribution" "webui" {
  # 既存設定...

  # v8: カスタムドメイン追加
  aliases = var.enable_custom_domain ? [local.webui_domain] : []

  viewer_certificate {
    # v8: カスタムドメイン有効時は ACM 証明書を使用
    acm_certificate_arn      = var.enable_custom_domain ? aws_acm_certificate.main[0].arn : null
    ssl_support_method       = var.enable_custom_domain ? "sni-only" : null
    minimum_protocol_version = var.enable_custom_domain ? "TLSv1.2_2021" : "TLSv1"
    cloudfront_default_certificate = var.enable_custom_domain ? false : true
  }
}
```

## 8. 前提条件・制約

### 前提条件

- v7 の全成果物が完成済みであること
- AWS アカウントが利用可能であること
- GitHub リポジトリが利用可能であること
- Route 53 でドメイン `sample-cicd.click` が購入・登録済みであること
- ドメインの Hosted Zone が Route 53 に存在すること

### 制約

- AWS リージョンは ap-northeast-1（東京）固定。ただし ACM 証明書・WAF は us-east-1
- Terraform Workspace で `dev` / `prod` の 2 環境を管理（実デプロイは `dev` のみ）
- CloudFront のカスタムドメインは Workspace に応じて動的に設定（`dev.sample-cicd.click` / `sample-cicd.click`）
- パスベースルーティング（`/api/*` → ALB）を継続。API 専用 CloudFront は作成しない
- ALB への直接 HTTPS アクセスは提供しない（CloudFront が HTTPS を終端）
- Terraform Remote State の S3 バケット・DynamoDB テーブルは bootstrap で別管理
- `prod` 環境への実デプロイは行わない（tfvars ファイルの更新のみ）
- ドメイン登録状態（Pending → Registered）が完了してから DNS 設定を行うこと
- `.click` TLD は DNSSEC 非対応のため、DNSSEC は設定しない

## 9. 用語集（v8 追加分）

| 用語 | 説明 |
|------|------|
| Route 53 Hosted Zone | ドメインの DNS レコードを管理するコンテナ。ドメイン購入時に自動作成される |
| A レコード (Alias) | AWS リソース（CloudFront, ALB 等）を指す DNS レコード。通常の A レコードと異なり IP アドレスではなく AWS リソースを指定 |
| ACM (AWS Certificate Manager) | SSL/TLS 証明書の管理サービス。パブリック証明書は無料で発行・自動更新（v7 用語集にも記載） |
| SAN (Subject Alternative Name) | 1 つの証明書で複数のドメイン名をカバーする拡張。ワイルドカード（`*.example.com`）を含められる |
| DNS 検証 | ACM 証明書の所有権を DNS レコード（CNAME）で証明する方式。Route 53 なら自動化可能 |
| Terraform Remote State | Terraform の state ファイルをリモートストレージ（S3 等）で管理する仕組み。チーム開発・CI/CD に必須 |
| Terraform Backend | state の保存先を定義する設定。`backend "s3"` で S3 + DynamoDB を指定 |
| State Lock | 同時に複数の `terraform apply` が実行されることを防ぐロック機構。DynamoDB で実現 |
| Bootstrap | Remote State 用リソース（S3, DynamoDB）自体は Remote State で管理できない「鶏と卵」問題を解決するための初期構築手順 |
| `terraform init -migrate-state` | 既存の state を新しい backend に移行するコマンド |
| TLD (Top-Level Domain) | ドメイン名の最後の部分（`.click`, `.com` 等） |
| `sni-only` | CloudFront の SSL 配信方式。Server Name Indication で証明書を選択。専用 IP 不要で追加費用なし |
