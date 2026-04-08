# 要件定義書 (v9)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-08 |
| バージョン | 9.0 |
| 前バージョン | [requirements_v8.md](requirements_v8.md) (v8.0) |

## 変更概要

v8（HTTPS + カスタムドメイン + Remote State）に以下を追加する:

- **CodeDeploy ブルー/グリーンデプロイ**: ECS のデプロイ方式をローリングデプロイから CodeDeploy による B/G デプロイに変更。2 つのターゲットグループ切り替えで即時ロールバック可能
- **Trivy コンテナイメージ脆弱性スキャン**: CI パイプラインで Docker イメージの HIGH/CRITICAL 脆弱性を自動検出、ビルド失敗で品質ゲート
- **tfsec Terraform セキュリティスキャン**: CI パイプラインで IaC のセキュリティベストプラクティス違反を自動検出
- **OIDC 認証（GitHub Actions → AWS）**: AWS Access Key を廃止し、OIDC プロバイダー + IAM ロールによるキーレス認証に移行
- **Terraform CI/CD 統合**: PR 時に `terraform plan` 結果を自動コメント、main マージ時に `terraform apply` を自動実行
- **Infracost コスト影響の自動表示**: PR 時にインフラ変更のコスト影響を自動計算し PR コメントに表示
- **GitHub Environments 承認ゲート**: dev 環境は自動デプロイ、prod 環境は承認ゲート付き（設定のみ）

## 1. プロジェクト概要

### 1.1 目的

v8 までで本番運用に近いインフラ基盤（カスタムドメイン、HTTPS、Remote State）が完成したが、CI/CD パイプラインには以下の課題がある:

1. **デプロイが不可逆的**: ローリングデプロイでは問題発生時のロールバックに時間がかかる。ブルー/グリーンデプロイで即時ロールバックを実現したい
2. **セキュリティスキャンなし**: コンテナイメージの脆弱性や Terraform コードのセキュリティ問題が CI で検出されない
3. **AWS 認証がシークレットキー依存**: 長期間有効な Access Key はセキュリティリスク。OIDC でキーレス認証に移行すべき
4. **IaC 変更が手動**: Terraform の plan/apply が手動実行。CI/CD に統合してインフラ変更の安全性と効率を向上させたい
5. **コスト影響が不透明**: インフラ変更時にコスト影響が事前に把握できない
6. **環境別の承認フローなし**: dev/prod の区別なくデプロイされる。prod は承認ゲートが必要

v9 ではこれらを解決し、エンタープライズレベルの CI/CD パイプラインを完成させる。

### 1.2 学習目標

| # | 学習テーマ | 内容 | デプロイ |
|---|-----------|------|:---:|
| 1 | CodeDeploy B/G デプロイ | deployment_controller = CODE_DEPLOY、ターゲットグループ切り替え、ロールバック | ✅ |
| 2 | Trivy | コンテナイメージ脆弱性スキャン、SARIF 出力、GitHub Security tab 統合 | ✅ |
| 3 | tfsec | Terraform セキュリティスキャン、CI 統合 | ✅ |
| 4 | OIDC 認証 | GitHub Actions OIDC プロバイダー、AssumeRoleWithWebIdentity、IAM ロール設計 | ✅ |
| 5 | Terraform CI/CD | PR 時 plan コメント、main マージ時 apply、Remote State 連携 | ✅ |
| 6 | Infracost | IaC コスト見積もり、PR コメント統合、無料プラン活用 | ✅ |
| 7 | GitHub Environments | 環境別設定、承認ゲート（Protection Rules）、シークレットのスコープ | ✅ |

### 1.3 スコープ

**スコープ内:**

- CodeDeploy ブルー/グリーンデプロイ
  - ECS サービスの `deployment_controller` を `CODE_DEPLOY` に変更
  - Blue / Green 2 つのターゲットグループ作成
  - CodeDeploy アプリケーション + デプロイグループ
  - CodeDeploy サービスロール（IAM）
  - ALB リスナーの設定更新
  - トラフィックシフト設定（AllAtOnce or Linear10PercentEvery1Minute）
  - CD ワークフローの CodeDeploy デプロイ対応
- CI パイプラインのセキュリティスキャン追加
  - Trivy: Docker build 後のイメージスキャン、HIGH/CRITICAL で失敗
  - tfsec: `infra/` ディレクトリのセキュリティスキャン
  - SARIF 出力で GitHub Security tab 統合（Trivy）
- OIDC 認証への移行
  - Terraform で IAM OIDC プロバイダーを定義
  - GitHub Actions 用 IAM ロール（AssumeRoleWithWebIdentity）を定義
  - ワークフローの認証方式を OIDC に切り替え
  - GitHub Secrets から `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` を削除
- Terraform CI/CD 統合
  - PR 時: `terraform plan` 実行 → 結果を PR コメントに自動投稿
  - main マージ時: `terraform apply -auto-approve` 実行
  - OIDC ロール経由で S3 / DynamoDB（Remote State）にアクセス
- Infracost
  - PR 時: plan 差分からコスト影響を計算し PR コメントに表示
  - Infracost API キー（無料プラン）の設定
- GitHub Environments
  - `dev` 環境: 自動デプロイ（承認不要）
  - `prod` 環境: 承認ゲート設定（Required Reviewers）
  - 環境別シークレット・変数の整理
- ワークフロー分割
  - 現行 `ci-cd.yml` → `ci.yml` + `cd.yml` に分割
  - `ci.yml`: lint → test → docker build → Trivy → tfsec → terraform plan → Infracost
  - `cd.yml`: ECR push → CodeDeploy B/G → Lambda update → Frontend S3 sync → terraform apply

**スコープ外:**

- ECS サービスの再作成手順の自動化（B/G 移行時は手動で `terraform state rm` + `import` が必要な場合がある）
- prod 環境への実デプロイ（承認ゲートの設定のみ）
- CodePipeline の導入（GitHub Actions で完結するため不要）
- カナリアデプロイ（B/G で十分。将来の拡張として検討可能）
- Terraform のモジュール化（v9 のスコープではない）
- アプリケーションコードの変更（v9 はインフラ・CI/CD のみ）
- マルチアカウント構成（単一 AWS アカウントで完結）

## 2. 機能要件

### 既存（v8 から継続）

| ID | 概要 | 変更 |
|----|------|------|
| FR-1 | Hello World API (`GET /`) | なし |
| FR-2 | ヘルスチェック (`GET /health`) | なし |
| FR-3 | CI パイプライン | **大幅変更**（Trivy, tfsec, terraform plan, Infracost 追加） |
| FR-4 | CD パイプライン | **大幅変更**（CodeDeploy B/G, OIDC, terraform apply, ワークフロー分割） |
| FR-5〜FR-9 | タスク CRUD API | なし |
| FR-10 | データベース永続化 | なし |
| FR-11 | ECS Auto Scaling | なし |
| FR-12〜FR-14 | イベント駆動処理 | なし |
| FR-15〜FR-18 | 添付ファイル CRUD API | なし |
| FR-19 | マルチ環境管理 | なし |
| FR-20〜FR-24 | Observability | なし |
| FR-25〜FR-29 | Web UI | なし |
| FR-30 | CORS ミドルウェア | なし |
| FR-31 | フロントエンド CI/CD | なし |
| FR-32〜FR-38 | Cognito 認証 | なし |
| FR-39〜FR-40 | WAF | なし |
| FR-41 | HTTPS + カスタムドメイン | なし |
| FR-42 | Route 53 Hosted Zone | なし |
| FR-43 | ACM 証明書 | なし |
| FR-44 | CloudFront カスタムドメイン | なし |
| FR-45 | サブドメイン設計 | なし |
| FR-46 | Terraform Remote State | なし（v9 Terraform CI/CD の前提基盤） |
| FR-47 | v3 既存コードとの関係 | なし |

### 新規

#### FR-48: CodeDeploy ブルー/グリーンデプロイ

| 項目 | 内容 |
|------|------|
| ID | FR-48 |
| 概要 | ECS のデプロイ方式を CodeDeploy による B/G デプロイに変更する |
| 現状 | `deployment_controller = "ECS"`（ローリングデプロイ） |
| 変更後 | `deployment_controller = "CODE_DEPLOY"`（B/G デプロイ） |
| ターゲットグループ | Blue TG（`*-tg-blue`）+ Green TG（`*-tg-green`）の 2 つ |
| ALB リスナー | 本番リスナー（Port 80）+ テストリスナー（Port 8080、オプション） |
| CodeDeploy アプリケーション | `sample-cicd-{env}` コンピューティングプラットフォーム: ECS |
| CodeDeploy デプロイグループ | `sample-cicd-{env}-dg`。Blue/Green 設定、自動ロールバック有効 |
| トラフィックシフト | `CodeDeployDefault.ECSAllAtOnce`（学習用）。将来は `Linear10PercentEvery1Minute` に変更可能 |
| ロールバック | デプロイ失敗時の自動ロールバック有効。手動ロールバックも可能 |
| IAM ロール | CodeDeploy サービスロール（`AWSCodeDeployRoleForECS` ポリシー） |
| appspec | `appspec.yml` は CD ワークフローで動的生成（TaskDefinition ARN + Container 情報） |
| Terraform リソース | `aws_codedeploy_app`, `aws_codedeploy_deployment_group`, `aws_iam_role` (CodeDeploy), `aws_lb_target_group` x2 |
| 備考 | 既存 ECS サービスは `deployment_controller` を変更できないため、`terraform apply` 時にサービスの再作成が必要（`lifecycle { create_before_destroy = true }` or 手動 state 操作） |

#### FR-49: Trivy コンテナイメージ脆弱性スキャン

| 項目 | 内容 |
|------|------|
| ID | FR-49 |
| 概要 | CI パイプラインでコンテナイメージの脆弱性を自動スキャンする |
| 実行タイミング | Docker build 後（CI ジョブ内） |
| ツール | Trivy（`aquasecurity/trivy-action`） |
| スキャン対象 | ビルドした Docker イメージ |
| 重大度フィルタ | HIGH, CRITICAL |
| 失敗条件 | HIGH または CRITICAL の脆弱性が検出された場合、CI を失敗させる |
| 出力形式 | テーブル形式（コンソール） + SARIF（GitHub Security tab） |
| SARIF アップロード | `github/codeql-action/upload-sarif` で GitHub Security tab に統合 |
| 備考 | 修正不可能な脆弱性（ベースイメージ由来等）は `.trivyignore` で除外可能 |

#### FR-50: tfsec Terraform セキュリティスキャン

| 項目 | 内容 |
|------|------|
| ID | FR-50 |
| 概要 | CI パイプラインで Terraform コードのセキュリティベストプラクティス違反を自動検出する |
| 実行タイミング | CI ジョブ内 |
| ツール | tfsec（`aquasecurity/tfsec-action`） |
| スキャン対象 | `infra/` ディレクトリ |
| 重大度フィルタ | HIGH, CRITICAL（WARNING は無視） |
| 失敗条件 | HIGH または CRITICAL が検出された場合、CI を失敗させる |
| 除外設定 | 学習用に許容する項目は `#tfsec:ignore:RULE_ID` でインラインコメント除外 |
| 備考 | tfsec は Trivy に統合されつつあるが、独立ツールとしてもまだ広く使われている |

#### FR-51: OIDC 認証（GitHub Actions → AWS）

| 項目 | 内容 |
|------|------|
| ID | FR-51 |
| 概要 | GitHub Actions から AWS への認証を Access Key から OIDC に移行する |
| 現状 | `secrets.AWS_ACCESS_KEY_ID` + `secrets.AWS_SECRET_ACCESS_KEY` で認証 |
| 変更後 | OIDC プロバイダー + IAM ロール（`AssumeRoleWithWebIdentity`） |
| OIDC プロバイダー | URL: `https://token.actions.githubusercontent.com`、Audience: `sts.amazonaws.com` |
| IAM ロール | `sample-cicd-github-actions-role`。信頼ポリシーで GitHub リポジトリ + ブランチを制限 |
| 信頼ポリシー条件 | `token.actions.githubusercontent.com:sub` で `repo:{owner}/{repo}:ref:refs/heads/main` + PR を制限 |
| IAM ポリシー | 現在の Access Key ユーザーと同等の権限（ECR, ECS, Lambda, S3, CloudFront, CodeDeploy, Terraform State 等） |
| ワークフロー変更 | `aws-actions/configure-aws-credentials` の `role-to-assume` パラメータに切り替え |
| `permissions` | ワークフローに `id-token: write` を追加（OIDC トークン取得に必要） |
| Terraform リソース | `aws_iam_openid_connect_provider`, `aws_iam_role` (GitHub Actions), `aws_iam_role_policy` or `aws_iam_role_policy_attachment` |
| 廃止 | GitHub Secrets から `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` を削除 |

#### FR-52: Terraform CI/CD 統合

| 項目 | 内容 |
|------|------|
| ID | FR-52 |
| 概要 | Terraform の plan/apply を CI/CD パイプラインに統合する |
| PR 時（CI） | `terraform init` → `terraform plan` 実行 → 結果を PR コメントに自動投稿 |
| main マージ時（CD） | `terraform init` → `terraform apply -auto-approve` 実行 |
| 前提条件 | v8 Remote State（S3 + DynamoDB）が構築済み |
| Backend 設定 | `-backend-config` オプションで S3 バケット・DynamoDB テーブルを指定 |
| Workspace | `terraform workspace select dev`（dev 環境固定） |
| PR コメント形式 | plan 出力をコードブロックで表示。追加/変更/削除リソース数のサマリ付き |
| 同時実行制御 | `concurrency` グループで同一環境の Terraform 操作を直列化 |
| Terraform バージョン | `hashicorp/setup-terraform` アクションでバージョン固定 |
| 権限 | OIDC ロール経由で S3 / DynamoDB / 各 AWS リソースにアクセス |
| 備考 | `infra/` 以下に変更がない場合は plan/apply をスキップするオプション検討 |

#### FR-53: Infracost コスト影響の自動表示

| 項目 | 内容 |
|------|------|
| ID | FR-53 |
| 概要 | PR 作成時にインフラ変更のコスト影響を自動計算し PR コメントに表示する |
| 実行タイミング | PR 作成 / 更新時（CI ジョブ内、terraform plan の後） |
| ツール | Infracost（`infracost/actions`） |
| 入力 | `terraform plan` の JSON 出力（`terraform show -json planfile`） |
| 出力 | PR コメントに月額コスト変化を表示（現在のコスト → 変更後のコスト → 差分） |
| API キー | Infracost Cloud API キー（無料プラン: 月 1,000 PR まで） |
| GitHub Secret | `INFRACOST_API_KEY` を GitHub Secrets に追加 |
| 備考 | コスト超過でビルド失敗にはしない（情報提供のみ） |

#### FR-54: GitHub Environments 承認ゲート

| 項目 | 内容 |
|------|------|
| ID | FR-54 |
| 概要 | GitHub Environments を使って環境別のデプロイ制御を行う |
| `dev` 環境 | 自動デプロイ（承認不要）。CD ワークフローの `environment: dev` で指定 |
| `prod` 環境 | Required Reviewers を設定（承認者が Approve 後にデプロイ可能）。v9 では設定のみ、実デプロイなし |
| 環境別シークレット | 将来の拡張用。v9 では `dev` 環境にのみ値を設定 |
| 環境変数 | `DEPLOY_ENV` をワークフローから Environment 変数に移行検討 |
| 備考 | GitHub Free プランでもパブリックリポジトリなら Environments + Protection Rules が利用可能 |

#### FR-55: ワークフロー分割

| 項目 | 内容 |
|------|------|
| ID | FR-55 |
| 概要 | 現行の `ci-cd.yml` を `ci.yml` と `cd.yml` に分割する |
| 現状 | `.github/workflows/ci-cd.yml`（CI + CD の 2 ジョブが 1 ファイル） |
| `ci.yml` | トリガー: `push` + `pull_request`。ジョブ: lint → test → docker build → Trivy → tfsec → terraform plan → Infracost（PR コメント） |
| `cd.yml` | トリガー: `push` to `main`（CI 成功後）or `workflow_run`。ジョブ: ECR push → CodeDeploy B/G → Lambda update → Frontend S3 sync → terraform apply |
| 認証 | 両ワークフローとも OIDC 認証 |
| `permissions` | `id-token: write`（OIDC）、`contents: read`、`pull-requests: write`（PR コメント）、`security-events: write`（SARIF アップロード） |
| 旧ファイル | `ci-cd.yml` は削除 |

## 3. 非機能要件

### 既存（v8 から継続）

| ID | 概要 | 変更 |
|----|------|------|
| NFR-1 | 可用性 | B/G デプロイで即時ロールバック可能（向上） |
| NFR-2 | セキュリティ | **大幅向上**（Trivy, tfsec, OIDC 移行） |
| NFR-3 | パフォーマンス | なし |
| NFR-4 | 運用性 | **向上**（Terraform CI/CD、Infracost、承認ゲート） |
| NFR-5 | コスト | 下記参照 |
| NFR-6 | スケーラビリティ | なし |
| NFR-7 | 疎結合性 | なし |
| NFR-8 | コンテンツ配信 | なし |
| NFR-9 | 可観測性 | なし |
| NFR-10 | 認証・認可 | なし |
| NFR-11 | DNS・ドメイン管理 | なし |

### 変更・追加

#### NFR-2: セキュリティ（更新）

| 項目 | 内容 |
|------|------|
| ID | NFR-2 |
| コンテナセキュリティ | Trivy で HIGH/CRITICAL 脆弱性を CI で検出。リリース前に品質ゲート |
| IaC セキュリティ | tfsec で Terraform コードのセキュリティ問題を CI で検出 |
| AWS 認証 | OIDC によるキーレス認証。長期間有効な Access Key を廃止 |
| 最小権限 | OIDC ロールの IAM ポリシーは必要最小限の権限に設定 |
| リポジトリ制限 | OIDC 信頼ポリシーで GitHub リポジトリ + ブランチを明示的に制限 |

#### NFR-4: 運用性（更新）

| 項目 | 内容 |
|------|------|
| ID | NFR-4 |
| デプロイ安全性 | B/G デプロイで即時ロールバック可能。デプロイ失敗時の自動ロールバック |
| IaC 変更の可視性 | PR コメントで terraform plan 結果とコスト影響を自動表示 |
| 承認フロー | prod 環境は承認ゲート付き。意図しないデプロイを防止 |
| ワークフロー分割 | CI/CD を分離することでジョブの独立性と可読性を向上 |

#### NFR-5: コスト（更新）

| 項目 | 内容 |
|------|------|
| ID | NFR-5 |
| CodeDeploy | **$0**（ECS デプロイは追加費用なし） |
| Trivy | **$0**（OSS、GitHub Action は無料） |
| tfsec | **$0**（OSS、GitHub Action は無料） |
| OIDC プロバイダー | **$0**（IAM リソースは無料） |
| Infracost | **$0**（無料プラン: 月 1,000 PR まで） |
| GitHub Environments | **$0**（パブリックリポジトリは無料） |
| v9 追加分合計 | 約 **$0/月** |
| 全体合計概算 | 約 **$98〜99/月**（v8 と同額。v9 追加分はすべて無料） |

#### NFR-12: デプロイ戦略（新規）

| 項目 | 内容 |
|------|------|
| ID | NFR-12 |
| デプロイ方式 | CodeDeploy ブルー/グリーンデプロイ |
| ロールバック時間 | 数秒（ターゲットグループ切り替え） |
| ダウンタイム | ゼロダウンタイム（B/G 切り替え） |
| トラフィックシフト | AllAtOnce（学習用）。Linear10PercentEvery1Minute に変更可能 |
| テストリスナー | Port 8080 でデプロイ後のテストが可能（オプション） |

#### NFR-13: CI/CD セキュリティ（新規）

| 項目 | 内容 |
|------|------|
| ID | NFR-13 |
| 認証方式 | OIDC（OpenID Connect）。短期トークンのみ使用 |
| シークレット管理 | AWS Access Key 不要。Infracost API キーのみ GitHub Secrets に保存 |
| 権限の最小化 | OIDC ロールは必要なサービスのみにアクセス許可 |
| リポジトリ制限 | 信頼ポリシーで特定の GitHub リポジトリ・ブランチに限定 |
| ワークフロー権限 | `permissions` ブロックで必要最小限のスコープを明示 |

## 4. AWS 構成

| サービス | 用途 | v8 | v9 |
|----------|------|:--:|:--:|
| ECR | Docker イメージレジストリ | o | o |
| ECS (Fargate) | コンテナ実行環境 | o | o（**deployment_controller = CODE_DEPLOY**） |
| ALB | ロードバランサー | o | o（**ターゲットグループ 2 つ**） |
| VPC | ネットワーク | o | o |
| IAM | ロールとポリシー | o | o（**OIDC プロバイダー + GitHub Actions ロール + CodeDeploy ロール追加**） |
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
| S3 (terraform-state) | Terraform state 保存 | o | o |
| CloudFront (attachments) | 添付ファイル CDN | o | o |
| CloudFront (webui) | Web UI CDN + API プロキシ | o | o |
| SNS | アラーム通知 | o | o |
| X-Ray | 分散トレーシング | o | o |
| Cognito | ユーザー認証 | o | o |
| WAF v2 | Web Application Firewall | o | o |
| ACM | SSL/TLS 証明書 | o | o |
| Route 53 | DNS 管理 | o | o |
| DynamoDB (terraform-lock) | Terraform state ロック | o | o |
| **CodeDeploy** | **B/G デプロイ管理** | - | **o** |
| **IAM OIDC Provider** | **GitHub Actions キーレス認証** | - | **o** |

リージョン: **ap-northeast-1**（東京）
※ ACM 証明書（CloudFront 用）は **us-east-1** に作成
※ WAF WebACL（CloudFront 用）は引き続き **us-east-1** に作成
※ IAM OIDC Provider は **グローバル**（リージョン不要）

## 5. 技術スタック

| カテゴリ | 技術 | v8 | v9 |
|----------|------|:--:|:--:|
| 言語 (Backend) | Python 3.12 | o | o |
| フレームワーク | FastAPI | o | o |
| ORM | SQLAlchemy | o | o |
| AWS SDK (Python) | boto3 | o | o |
| JWT ライブラリ | python-jose[cryptography] | o | o |
| トレーシング | aws-xray-sdk | o | o |
| IaC | Terraform | o | o |
| CI/CD | GitHub Actions | o | o（**ワークフロー分割、OIDC 認証**） |
| Lint (Python) | ruff | o | o |
| テスト | pytest + moto | o | o |
| 言語 (Frontend) | JavaScript (JSX) | o | o |
| フレームワーク (Frontend) | React 19 | o | o |
| ビルドツール | Vite | o | o |
| 認証 SDK | amazon-cognito-identity-js | o | o |
| **脆弱性スキャン** | **Trivy** | - | **o** |
| **IaC セキュリティスキャン** | **tfsec** | - | **o** |
| **コスト見積もり** | **Infracost** | - | **o** |
| **デプロイ管理** | **AWS CodeDeploy** | - | **o** |

## 6. 環境変数

### GitHub Secrets / Variables の変更

| Variable | 変更 | 説明 |
|----------|------|------|
| `AWS_ACCESS_KEY_ID` | **廃止** | OIDC に移行。GitHub Secrets から削除 |
| `AWS_SECRET_ACCESS_KEY` | **廃止** | OIDC に移行。GitHub Secrets から削除 |
| `INFRACOST_API_KEY` | **追加** | Infracost Cloud API キー（GitHub Secrets に追加） |
| `AWS_OIDC_ROLE_ARN` | **追加** | OIDC IAM ロールの ARN（GitHub Secrets or Variables に追加） |
| `CUSTOM_DOMAIN_NAME` | 維持 | GitHub Variables。カスタムドメイン名 |

### ワークフロー permissions

| Permission | CI | CD | 用途 |
|-----------|:--:|:--:|------|
| `id-token: write` | ✅ | ✅ | OIDC トークン取得 |
| `contents: read` | ✅ | ✅ | リポジトリクローン |
| `pull-requests: write` | ✅ | - | PR コメント（terraform plan、Infracost） |
| `security-events: write` | ✅ | - | SARIF アップロード（Trivy） |

### アプリケーション環境変数

v9 ではアプリケーションコードの変更はなし。環境変数の追加・変更なし。

### Terraform 変数の追加

| Variable | 説明 |
|----------|------|
| `github_repo` | GitHub リポジトリ（`owner/repo` 形式）。OIDC 信頼ポリシーで使用 |
| `codedeploy_traffic_routing` | トラフィックシフト方式（`AllAtOnce` or `Linear10PercentEvery1Minute`）。デフォルト: `AllAtOnce` |
| `enable_test_listener` | テストリスナー（Port 8080）を作成するか。デフォルト: `false` |

## 7. コスト見積もり

| 項目 | 月額 |
|------|------|
| 既存インフラ（v8 まで） | 約 $98〜99 |
| CodeDeploy | $0（ECS デプロイは無料） |
| IAM OIDC Provider | $0（IAM リソースは無料） |
| Trivy（GitHub Actions） | $0（OSS） |
| tfsec（GitHub Actions） | $0（OSS） |
| Infracost（無料プラン） | $0 |
| GitHub Environments | $0（パブリックリポジトリ） |
| **v9 全体合計** | **約 $98〜99/月** |

※ v9 の追加要素はすべて無料サービス / 無料枠内のため、月額コスト増加なし。

## 8. 前提条件・制約

### 前提条件

- v8 の全成果物が完成済みであること
- Terraform Remote State（S3 + DynamoDB）が構築・運用中であること
- AWS アカウントが利用可能であること
- GitHub リポジトリが利用可能であること（パブリックリポジトリ推奨: Environments の Protection Rules 利用のため）
- Infracost のアカウント登録（無料）と API キー取得が完了していること
- CodeDeploy 移行時に ECS サービスの再作成が必要なことを理解していること

### 制約

- AWS リージョンは ap-northeast-1（東京）固定。ただし ACM 証明書・WAF は us-east-1
- Terraform Workspace で `dev` / `prod` の 2 環境を管理（実デプロイは `dev` のみ）
- `prod` 環境への実デプロイは行わない（GitHub Environments の設定のみ）
- ECS サービスの `deployment_controller` は作成後に変更不可。B/G 移行時はサービスの再作成が必要
  - 方法 1: `terraform state rm` → リソース削除 → `terraform apply` で新規作成
  - 方法 2: `terraform taint` で強制再作成
  - いずれも一時的なダウンタイムが発生する可能性がある
- OIDC IAM ロールの信頼ポリシーは特定の GitHub リポジトリに限定すること（セキュリティ要件）
- Infracost は Terraform plan の JSON 出力が必要（`terraform show -json`）
- tfsec の一部ルールは学習用インフラでは過検知となる場合がある（適宜 `#tfsec:ignore` で除外）
- CodeDeploy の `appspec.yml` はワークフロー内で動的生成する（リポジトリに静的ファイルとして持たない）
- GitHub Actions の `workflow_run` トリガーはデフォルトブランチのワークフローファイルを参照する制約がある
- CodeDeploy B/G デプロイ時は `aws-actions/amazon-ecs-deploy-task-definition` の `codedeploy-appspec` / `codedeploy-application` / `codedeploy-deployment-group` パラメータを使用

## 9. 実装方針

### 9.1 ワークフロー分割の設計

```
.github/workflows/
  ci.yml       # CI: 全 push / PR でトリガー
  cd.yml       # CD: main push でトリガー（CI 成功後）
  ci-cd.yml    # 削除（旧ファイル）
```

#### ci.yml の構成

```yaml
# トリガー: push + pull_request (main)
jobs:
  lint-test:          # ruff + pytest
  build:              # Docker build + Trivy スキャン
  security-scan:      # tfsec
  terraform-plan:     # terraform plan + PR コメント
  infracost:          # Infracost PR コメント（PR 時のみ）
```

#### cd.yml の構成

```yaml
# トリガー: push to main (workflow_run で CI 成功後)
jobs:
  deploy:
    environment: dev  # GitHub Environments
    steps:
      - OIDC 認証
      - ECR push
      - CodeDeploy B/G デプロイ
      - Lambda update
      - Frontend S3 sync + CloudFront invalidation
  terraform-apply:
    environment: dev
    steps:
      - OIDC 認証
      - terraform apply -auto-approve
```

### 9.2 Terraform ファイル構成の変更

```
infra/
  codedeploy.tf      # 新規: CodeDeploy アプリケーション + デプロイグループ
  oidc.tf            # 新規: OIDC プロバイダー + GitHub Actions IAM ロール
  alb.tf             # 変更: Blue/Green ターゲットグループ追加
  ecs.tf             # 変更: deployment_controller = CODE_DEPLOY
  iam.tf             # 変更: CodeDeploy サービスロール追加
  monitoring.tf      # 変更: ターゲットグループ参照の更新（必要に応じて）
  ...（その他は変更なし）
```

### 9.3 CodeDeploy 移行手順

1. Terraform で Blue/Green ターゲットグループ + CodeDeploy リソースを定義
2. 既存 ECS サービスを `terraform state rm` で state から除外
3. ECS サービスを手動削除（AWS CLI or Console）
4. `terraform apply` で新しい ECS サービス（`deployment_controller = CODE_DEPLOY`）を作成
5. CD ワークフローを CodeDeploy デプロイに変更
6. テストデプロイで B/G 切り替えを確認

### 9.4 OIDC 移行手順

1. Terraform で OIDC プロバイダー + IAM ロールを作成（`terraform apply`）
2. GitHub Secrets に `AWS_OIDC_ROLE_ARN` を追加
3. ワークフローの認証ステップを OIDC に切り替え
4. テストデプロイで OIDC 認証を確認
5. GitHub Secrets から `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` を削除
6. IAM ユーザーの Access Key を無効化 / 削除

### 9.5 ALB 更新イメージ

```hcl
# infra/alb.tf（変更部分）

# Blue Target Group (本番トラフィック)
resource "aws_lb_target_group" "blue" {
  name        = "${local.prefix}-tg-blue"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }
}

# Green Target Group (新バージョンのテスト用)
resource "aws_lb_target_group" "green" {
  name        = "${local.prefix}-tg-green"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }
}

# HTTP Listener (Blue TG を初期ターゲットに)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }
}
```

### 9.6 CodeDeploy 定義イメージ

```hcl
# infra/codedeploy.tf

resource "aws_codedeploy_app" "main" {
  compute_platform = "ECS"
  name             = local.prefix
}

resource "aws_codedeploy_deployment_group" "main" {
  app_name               = aws_codedeploy_app.main.name
  deployment_group_name  = "${local.prefix}-dg"
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  service_role_arn       = aws_iam_role.codedeploy.arn

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.main.name
    service_name = aws_ecs_service.app.name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.http.arn]
      }

      target_group {
        name = aws_lb_target_group.blue.name
      }

      target_group {
        name = aws_lb_target_group.green.name
      }
    }
  }
}
```

## 10. 用語集（v9 追加分）

| 用語 | 説明 |
|------|------|
| Blue/Green デプロイ | 本番環境（Blue）と同じ構成の新環境（Green）を用意し、トラフィックを切り替えるデプロイ手法。問題発生時は即座に Blue に戻せる |
| CodeDeploy | AWS のデプロイ自動化サービス。ECS の B/G デプロイをサポートし、トラフィックシフトとロールバックを管理する |
| ターゲットグループ | ALB がトラフィックを転送する先のグループ。B/G デプロイでは 2 つのターゲットグループを切り替える |
| トラフィックシフト | トラフィックを旧バージョンから新バージョンに切り替える方式。AllAtOnce（一括）、Linear（段階的）、Canary（少量テスト後に全量）がある |
| appspec.yml | CodeDeploy がデプロイ手順を定義するファイル。ECS の場合、TaskDefinition と Container 情報を指定 |
| Trivy | Aqua Security が開発するOSS の脆弱性スキャナー。コンテナイメージ、ファイルシステム、IaC のスキャンが可能 |
| SARIF | Static Analysis Results Interchange Format。静的解析ツールの結果を標準化したフォーマット。GitHub Security tab と統合可能 |
| tfsec | Terraform コードのセキュリティスキャンツール。ベストプラクティス違反やセキュリティリスクを検出する |
| OIDC (OpenID Connect) | OAuth 2.0 の上位レイヤーの認証プロトコル。GitHub Actions が AWS STS に短期トークンを要求し、IAM ロールを引き受ける |
| AssumeRoleWithWebIdentity | OIDC トークンを使って IAM ロールを引き受ける STS API。Access Key 不要でセキュア |
| Infracost | Terraform のコスト見積もりツール。plan 差分からインフラ変更のコスト影響を計算する |
| GitHub Environments | GitHub リポジトリの環境設定機能。Protection Rules（承認ゲート等）と環境別シークレット / 変数を管理 |
| Protection Rules | GitHub Environments の保護ルール。Required Reviewers（承認者）、Wait Timer（待機時間）等を設定可能 |
| workflow_run | GitHub Actions のトリガーイベント。別のワークフローの完了をトリガーにワークフローを実行する |
| concurrency | GitHub Actions の同時実行制御。同一グループのワークフローが同時に実行されることを防ぐ |
