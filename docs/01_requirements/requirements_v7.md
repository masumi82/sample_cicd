# 要件定義書 (v7)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-07 |
| バージョン | 7.0 |
| 前バージョン | [requirements_v6.md](requirements_v6.md) (v6.0) |

## 変更概要

v6（Observability + Web UI）に以下を追加する:

- **認証・認可**: Amazon Cognito User Pool による JWT 認証。API エンドポイントの保護、React SPA にログイン画面追加
- **WAF（Web Application Firewall）**: CloudFront + ALB に WAF を適用し、レートリミット・一般的な攻撃パターンを防御
- **HTTPS（カスタムドメイン）**: ACM 証明書 + Route53 による独自ドメイン HTTPS 化（オプション）

## 1. プロジェクト概要

### 1.1 目的

v6 で構築した Web UI + API 基盤に、本番運用で最も重要な **認証・認可** と **WAF** を追加する。
現状は全 API エンドポイントがパブリックであり、誰でもタスクの作成・削除が可能な状態。
Amazon Cognito による JWT 認証でアクセスを制限し、WAF で一般的な Web 攻撃を防御する。

### 1.2 学習目標

| # | 学習テーマ | 内容 | デプロイ |
|---|-----------|------|:---:|
| 1 | Amazon Cognito | User Pool、App Client、JWT トークン（ID / Access / Refresh） | ✅ |
| 2 | JWT 認証ミドルウェア | FastAPI で Authorization ヘッダーの JWT を検証 | ✅ |
| 3 | React 認証フロー | ログイン / サインアップ / ログアウト画面、トークン管理 | ✅ |
| 4 | 保護ルーティング | 未認証ユーザーのリダイレクト、API リクエストへのトークン付与 | ✅ |
| 5 | AWS WAF v2 | マネージドルールグループ、レートリミット、カスタムルール | ✅ |
| 6 | HTTPS + カスタムドメイン | ACM 証明書、Route53、CloudFront 代替ドメイン名 | オプション |

### 1.3 スコープ

**スコープ内:**

- Amazon Cognito User Pool + App Client（SPA 向け、クライアントシークレットなし）
- FastAPI JWT 認証ミドルウェア（`Authorization: Bearer <token>` ヘッダー検証）
- API エンドポイントの保護（`GET /`, `GET /health` 以外は認証必須）
- React SPA ログイン / サインアップ / ログアウト画面
- React 保護ルーティング（未認証時はログイン画面にリダイレクト）
- React API クライアントへのトークン自動付与
- AWS WAF v2（CloudFront WebACL）
  - AWS マネージドルール: AWSManagedRulesCommonRuleSet（一般的な攻撃防御）
  - AWS マネージドルール: AWSManagedRulesKnownBadInputsRuleSet（既知の悪意ある入力防御）
  - レートリミットルール（IP あたりのリクエスト数制限）
- Terraform リソース追加（Cognito, WAF）
- CI/CD パイプライン更新（変更なし or 軽微な変更）
- HTTPS + カスタムドメイン（ACM + Route53 + CloudFront 代替ドメイン名）— **オプション: ドメイン保有時のみ**

**スコープ外:**

- Cognito Hosted UI（自前ログイン画面を構築）
- ソーシャルログイン（Google, GitHub 等の ID プロバイダ連携）
- MFA（多要素認証）— 設計のみ。有効化は手動
- Cognito グループによるロールベースアクセス制御（RBAC）
- API Gateway（ALB + FastAPI ミドルウェアで認証を実装）
- OAuth2 の Authorization Code Flow with PKCE（SPA では Cognito SDK を使用）
- Bot Control / IP Reputation（WAF の有料マネージドルール）
- WAF ログ分析（S3 / Kinesis Firehose 連携）
- フロントエンドのユニットテスト / E2E テスト

## 2. 機能要件

### 既存（v6 から継続）

| ID | 概要 | 変更 |
|----|------|------|
| FR-1 | Hello World API (`GET /`) | なし |
| FR-2 | ヘルスチェック (`GET /health`) | なし |
| FR-3 | CI パイプライン | なし |
| FR-4 | CD パイプライン | Cognito 設定注入を追加 |
| FR-5〜FR-9 | タスク CRUD API | **認証必須**（JWT Bearer トークン） |
| FR-10 | データベース永続化 | なし |
| FR-11 | ECS Auto Scaling | なし |
| FR-12〜FR-14 | イベント駆動処理 | なし |
| FR-15〜FR-18 | 添付ファイル CRUD API | **認証必須**（JWT Bearer トークン） |
| FR-19 | マルチ環境管理 | なし |
| FR-20〜FR-24 | Observability | なし |
| FR-25〜FR-29 | Web UI | ログイン必須化、トークン付与 |
| FR-30 | CORS ミドルウェア | `Authorization` ヘッダーを `allow_headers` に追加 |
| FR-31 | フロントエンド CI/CD | Cognito 設定注入を追加 |

### 新規

#### FR-32: Cognito User Pool

| 項目 | 内容 |
|------|------|
| ID | FR-32 |
| 概要 | ユーザー認証基盤として Cognito User Pool を作成する |
| ユーザー属性 | email（必須、ログイン ID として使用） |
| パスワードポリシー | 最低 8 文字、大文字・小文字・数字・記号を要求 |
| 自己サインアップ | 有効（email 確認コードによる検証） |
| App Client | SPA 向け（クライアントシークレットなし） |
| トークン有効期間 | ID Token: 1 時間、Access Token: 1 時間、Refresh Token: 30 日 |
| Terraform リソース | `aws_cognito_user_pool`, `aws_cognito_user_pool_client` |

#### FR-33: API JWT 認証ミドルウェア

| 項目 | 内容 |
|------|------|
| ID | FR-33 |
| 概要 | FastAPI ミドルウェアで JWT トークンを検証し、未認証リクエストを拒否する |
| 認証ヘッダー | `Authorization: Bearer <ID Token>` |
| 検証内容 | 署名検証（JWKS）、有効期限、issuer（User Pool URL）、audience（App Client ID） |
| 公開エンドポイント | `GET /`、`GET /health`（認証不要） |
| 保護エンドポイント | `GET/POST/PUT/DELETE /tasks*`（認証必須） |
| 未認証レスポンス | `401 Unauthorized` + `{"detail": "Not authenticated"}` |
| トークン期限切れ | `401 Unauthorized` + `{"detail": "Token expired"}` |
| 環境変数 | `COGNITO_USER_POOL_ID`, `COGNITO_APP_CLIENT_ID` |
| Graceful degradation | 環境変数未設定時は認証スキップ（ローカル開発用） |
| ライブラリ | `python-jose[cryptography]`（JWT デコード + JWKS 検証） |

#### FR-34: React ログイン画面

| 項目 | 内容 |
|------|------|
| ID | FR-34 |
| 概要 | ユーザーがメールアドレスとパスワードでログインする |
| 入力項目 | メールアドレス（必須）、パスワード（必須） |
| ログイン処理 | Cognito `InitiateAuth` API → JWT トークン取得 → localStorage に保存 |
| エラー表示 | 認証失敗時にエラーメッセージ表示（「メールアドレスまたはパスワードが正しくありません」） |
| ログイン後 | タスク一覧画面にリダイレクト |
| ライブラリ | `amazon-cognito-identity-js` |

#### FR-35: React サインアップ画面

| 項目 | 内容 |
|------|------|
| ID | FR-35 |
| 概要 | 新規ユーザーがアカウントを作成する |
| 入力項目 | メールアドレス（必須）、パスワード（必須）、パスワード確認（必須） |
| フロー | サインアップ → email に確認コード送信 → 確認コード入力 → アカウント有効化 |
| バリデーション | パスワードポリシー違反時にエラーメッセージ表示 |
| 確認後 | ログイン画面にリダイレクト |

#### FR-36: React ログアウト・セッション管理

| 項目 | 内容 |
|------|------|
| ID | FR-36 |
| 概要 | ログアウトとセッション管理を行う |
| ログアウト | localStorage からトークン削除 → ログイン画面にリダイレクト |
| セッション維持 | ページリロード時に localStorage のトークンを読み取り、有効であればログイン状態を維持 |
| トークン期限切れ | API 呼び出しで 401 を受けた場合、Refresh Token でトークン更新。失敗時はログイン画面にリダイレクト |
| UI 表示 | ヘッダーにユーザーのメールアドレスとログアウトボタンを表示 |

#### FR-37: React 保護ルーティング

| 項目 | 内容 |
|------|------|
| ID | FR-37 |
| 概要 | 未認証ユーザーのアクセスを制限する |
| 保護対象 | タスク一覧、タスク作成、タスク詳細の全ルート |
| 公開ルート | `/login`、`/signup`、`/confirm` |
| 未認証アクセス | ログイン画面にリダイレクト（リダイレクト元 URL を保持） |
| ログイン後 | 元のリダイレクト元 URL に遷移（デフォルトはタスク一覧） |

#### FR-38: API リクエストへのトークン自動付与

| 項目 | 内容 |
|------|------|
| ID | FR-38 |
| 概要 | API クライアントが自動的に JWT トークンを付与する |
| 実装 | `fetch` ラッパーの `headers` に `Authorization: Bearer <token>` を追加 |
| トークン取得元 | localStorage |
| 401 ハンドリング | Refresh Token でリフレッシュを試行 → 失敗時はログイン画面にリダイレクト |

#### FR-39: WAF — マネージドルール

| 項目 | 内容 |
|------|------|
| ID | FR-39 |
| 概要 | AWS マネージドルールグループで一般的な Web 攻撃を防御する |
| AWSManagedRulesCommonRuleSet | SQL インジェクション、XSS、パストラバーサル等の防御 |
| AWSManagedRulesKnownBadInputsRuleSet | Log4j、既知の脆弱性を狙う入力の防御 |
| 適用先 | CloudFront ディストリビューション（Web UI + API） |
| Terraform リソース | `aws_wafv2_web_acl`, `aws_wafv2_web_acl_association` |

#### FR-40: WAF — レートリミット

| 項目 | 内容 |
|------|------|
| ID | FR-40 |
| 概要 | IP アドレスあたりのリクエスト数を制限する |
| 閾値 | dev: 2000 リクエスト/5分、prod: 1000 リクエスト/5分 |
| アクション | 閾値超過時に 403 Forbidden を返す |
| 対象 | CloudFront 経由の全リクエスト |

#### FR-41: HTTPS + カスタムドメイン（オプション）

| 項目 | 内容 |
|------|------|
| ID | FR-41 |
| 概要 | 独自ドメインで HTTPS アクセスを可能にする |
| 前提 | Route53 に登録済みのドメインを保有していること |
| ACM | `us-east-1` リージョンで証明書を作成（CloudFront 用は us-east-1 必須） |
| DNS 検証 | Route53 CNAME レコードによる自動検証 |
| CloudFront | 代替ドメイン名（Alternate Domain Names）を設定 |
| Terraform リソース | `aws_acm_certificate`, `aws_route53_record`, CloudFront 更新 |
| 制御 | `enable_custom_domain` 変数で ON/OFF。デフォルト `false` |

## 3. 非機能要件

### 既存（v6 から継続）

| ID | 概要 | 変更 |
|----|------|------|
| NFR-1 | 可用性 | なし |
| NFR-2 | セキュリティ | Cognito + WAF で大幅強化（下記参照） |
| NFR-3 | パフォーマンス | WAF レートリミットで過負荷防止 |
| NFR-4 | 運用性 | なし |
| NFR-5 | コスト | 下記参照 |
| NFR-6 | スケーラビリティ | なし |
| NFR-7 | 疎結合性 | なし |
| NFR-8 | コンテンツ配信 | なし |
| NFR-9 | 可観測性 | なし |

### 変更・追加

#### NFR-2: セキュリティ（更新）

| 項目 | 内容 |
|------|------|
| ID | NFR-2 |
| 認証 | Cognito User Pool による JWT 認証。全 API エンドポイント（`/`, `/health` 除く）で認証必須 |
| トークン管理 | ID Token + Access Token（1 時間有効）、Refresh Token（30 日有効） |
| JWKS 検証 | Cognito の公開鍵（JWKS エンドポイント）でトークン署名を検証。鍵はキャッシュ |
| WAF 防御 | SQL インジェクション、XSS、パストラバーサル、Log4j 等の一般的な攻撃を防御 |
| レートリミット | IP あたり 2000 req/5min（dev）で DDoS 軽減 |
| CORS | `Authorization` ヘッダーを許可ヘッダーに追加 |

#### NFR-5: コスト（更新）

| 項目 | 内容 |
|------|------|
| ID | NFR-5 |
| Cognito | 無料枠: 月 50,000 MAU → 学習用は実質 **$0** |
| WAF | WebACL: $5.00/月 + ルール: $1.00/ルール/月 × 3 = **$8.00/月** |
| WAF リクエスト | $0.60/100 万リクエスト → 学習用は実質 **$0** |
| ACM | 無料（パブリック証明書） |
| Route53 | ホストゾーン: $0.50/月（ドメイン保有時のみ） |
| v7 追加分合計 | 約 **$8.00〜8.50/月** |
| 全体合計概算 | 約 **$97〜98/月**（v6 $89 + v7 $8.50） |

#### NFR-10: 認証・認可（新規）

| 項目 | 内容 |
|------|------|
| ID | NFR-10 |
| 認証方式 | JWT (JSON Web Token) ベースのステートレス認証 |
| トークン保管 | ブラウザの localStorage（学習目的。本番では httpOnly Cookie 推奨） |
| セッション有効期間 | ID/Access Token: 1 時間、Refresh Token: 30 日 |
| ブルートフォース防止 | Cognito 側で自動ロックアウト（5 回失敗で一時ブロック） |
| JWKS キャッシュ | アプリ起動時に JWKS を取得しメモリにキャッシュ。1 時間ごとに更新 |

## 4. AWS 構成

| サービス | 用途 | v6 | v7 |
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
| Lambda | イベントハンドラ × 3 | o | o |
| EventBridge | イベントバス + Scheduler | o | o |
| VPC エンドポイント | Lambda 用 | o | o |
| S3 (attachments) | 添付ファイルストレージ | o | o |
| S3 (webui) | Web UI 静的ホスティング | o | o |
| CloudFront (attachments) | 添付ファイル CDN | o | o |
| CloudFront (webui) | Web UI CDN + API プロキシ | o | o |
| SNS | アラーム通知 | o | o |
| X-Ray | 分散トレーシング | o | o |
| **Cognito** | **ユーザー認証（User Pool + App Client）** | - | **o** |
| **WAF v2** | **Web Application Firewall** | - | **o** |
| **ACM** | **SSL/TLS 証明書（オプション）** | - | **o** (optional) |
| **Route53** | **DNS（オプション）** | - | **o** (optional) |

リージョン: **ap-northeast-1**（東京）
※ ACM 証明書は **us-east-1** に作成（CloudFront の要件）

## 5. 技術スタック

| カテゴリ | 技術 | v6 | v7 |
|----------|------|:--:|:--:|
| 言語 (Backend) | Python 3.12 | o | o |
| フレームワーク | FastAPI | o | o（JWT ミドルウェア追加） |
| ORM | SQLAlchemy | o | o |
| AWS SDK (Python) | boto3 | o | o |
| **JWT ライブラリ** | **python-jose[cryptography]** | - | **o** |
| トレーシング | aws-xray-sdk | o | o |
| IaC | Terraform | o | o（Cognito, WAF 追加） |
| CI/CD | GitHub Actions | o | o |
| Lint (Python) | ruff | o | o |
| テスト | pytest + moto | o | o |
| 言語 (Frontend) | JavaScript (JSX) | o | o |
| フレームワーク (Frontend) | React 19 | o | o（認証画面追加） |
| ビルドツール | Vite | o | o |
| **認証 SDK** | **amazon-cognito-identity-js** | - | **o** |

## 6. 前提条件・制約

### 前提条件

- v6 の全成果物が完成済みであること
- AWS アカウントが利用可能であること
- GitHub リポジトリが利用可能であること
- Node.js 20 がローカル環境にインストールされていること
- HTTPS + カスタムドメイン機能を使用する場合、Route53 にドメインが登録済みであること

### 制約

- AWS リージョンは ap-northeast-1（東京）固定。ただし ACM 証明書は us-east-1
- Terraform Workspace で `dev` / `prod` の 2 環境を管理（実デプロイは `dev` のみ）
- Cognito User Pool はリージョン固定（ap-northeast-1）
- JWT 検証は `COGNITO_USER_POOL_ID`, `COGNITO_APP_CLIENT_ID` 環境変数で制御。未設定時は認証スキップ（Graceful degradation、ローカル開発用）
- トークン保管は localStorage（学習目的。httpOnly Cookie は v7 スコープ外）
- ソーシャルログイン・MFA は v7 スコープ外
- WAF は CloudFront に適用（ALB 直接アクセスは CloudFront 経由のため WAF でカバー）
- WAF ログ分析（S3 / Kinesis Firehose）は v7 スコープ外
- HTTPS + カスタムドメインは `enable_custom_domain` 変数で制御。デフォルト無効
- `prod` 環境への実デプロイは行わない（tfvars ファイルの更新のみ）

## 7. 用語集（v7 追加分）

| 用語 | 説明 |
|------|------|
| Amazon Cognito | AWS のマネージド認証サービス。User Pool でユーザー管理・認証を行い、JWT トークンを発行する |
| User Pool | Cognito のユーザーディレクトリ。サインアップ・サインイン・パスワードリセット等の認証機能を提供 |
| App Client | User Pool に紐づくアプリケーション設定。SPA では「クライアントシークレットなし」で作成 |
| JWT (JSON Web Token) | ヘッダー.ペイロード.署名 の 3 部構成のトークン。ステートレスな認証に使用 |
| ID Token | ユーザーのプロフィール情報（email 等）を含む JWT。API 認証に使用 |
| Access Token | ユーザーのアクセス権限を含む JWT。Cognito API 呼び出しに使用 |
| Refresh Token | ID/Access Token の再発行に使用する長寿命トークン |
| JWKS (JSON Web Key Set) | JWT の署名を検証するための公開鍵セット。Cognito が `/.well-known/jwks.json` で公開 |
| AWS WAF v2 | Web Application Firewall。HTTP リクエストをルールに基づいてフィルタリングする |
| WebACL | WAF のルールセット。CloudFront や ALB にアタッチして適用する |
| マネージドルールグループ | AWS が提供・管理するルールセット。AWSManagedRulesCommonRuleSet 等 |
| レートリミット | 一定時間内のリクエスト数を制限し、DDoS やブルートフォース攻撃を緩和する |
| ACM (AWS Certificate Manager) | SSL/TLS 証明書の管理サービス。パブリック証明書は無料で発行・自動更新 |
| Route53 | AWS の DNS サービス。ドメインの登録・DNS レコード管理・ヘルスチェックを提供 |
| CORS `Authorization` ヘッダー | JWT トークンを送るための HTTP ヘッダー。CORS 設定で明示的に許可が必要 |
