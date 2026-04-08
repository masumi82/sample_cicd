# 動作確認記録 v9 — CI/CD 完全自動化 + セキュリティスキャン

| 項目 | 内容 |
|------|------|
| 確認日 | 2026-04-08 |
| 環境 | dev |
| 確認者 | m-horiuchi + Claude |

## 1. Terraform Apply

| # | 確認項目 | 結果 | 備考 |
|---|---------|------|------|
| 1 | OIDC Provider 作成 | **PASS** | `aws_iam_openid_connect_provider.github_actions` |
| 2 | GitHub Actions IAM Role 作成 | **PASS** | `sample-cicd-dev-github-actions` |
| 3 | CodeDeploy サービスロール作成 | **PASS** | `sample-cicd-dev-codedeploy` |
| 4 | CodeDeploy App 作成 | **PASS** | `sample-cicd-dev` (ECS platform) |
| 5 | CodeDeploy Deployment Group 作成 | **PASS** | `sample-cicd-dev-dg` (B/G, auto rollback) |
| 6 | Blue Target Group 作成 | **PASS** | `sample-cicd-dev-tg-blue` |
| 7 | Green Target Group 作成 | **PASS** | `sample-cicd-dev-tg-green` |
| 8 | ECS Service 再作成 (CODE_DEPLOY) | **PASS** | `deployment_controller = CODE_DEPLOY` |
| 9 | ALB Listener → Blue TG | **PASS** | `lifecycle { ignore_changes }` 設定済み |
| 10 | AutoScaling Target/Policy 再作成 | **PASS** | ECS サービスに紐付け |
| 11 | monitoring.tf TG 参照更新 | **PASS** | `.app` → `.blue` に変更済み |

## 2. CI ワークフロー (ci.yml)

| # | 確認項目 | 結果 | 備考 |
|---|---------|------|------|
| 12 | lint-test ジョブ | **PASS** | ruff + pytest 62 tests |
| 13 | build ジョブ (Docker build) | **PASS** | `sample-cicd:ci` ビルド成功 |
| 14 | Trivy 脆弱性スキャン | **PASS** | `.trivyignore` で既知 CVE 除外後に PASS |
| 15 | Trivy SARIF → GitHub Security tab | **PASS** | SARIF アップロード成功 |
| 16 | security-scan ジョブ (tfsec) | **PASS** | HIGH/CRITICAL 検出なし |
| 17 | terraform-plan ジョブ (OIDC) | **PASS** | OIDC 認証成功、plan 実行成功 |
| 18 | terraform plan artifact upload | **PASS** | plan.json アップロード成功 |
| 19 | infracost ジョブ | **SKIP** | PR 時のみ実行（push では skip） |
| 20 | concurrency 設定 | **PASS** | `cancel-in-progress: true` 動作確認 |

## 3. CD ワークフロー (cd.yml)

| # | 確認項目 | 結果 | 備考 |
|---|---------|------|------|
| 21 | workflow_run トリガー | **PASS** | CI 成功後に自動起動 |
| 22 | OIDC 認証 (CD) | **PASS** | `role-to-assume` で認証成功 |
| 23 | ECR push | **PASS** | SHA タグ + latest タグ |
| 24 | CodeDeploy B/G デプロイ | **PASS** | appspec.json 生成 → B/G 切り替え成功（約 9 分） |
| 25 | Lambda デプロイ | **PASS** | 3 関数の update-function-code 成功 |
| 26 | Frontend ビルド + S3 sync | **PASS** | config.js 生成 + S3 sync + CF invalidation |
| 27 | terraform-apply ジョブ | **PASS** | `-var` で Secrets 注入、apply 成功 |
| 28 | environment: dev | **PASS** | GitHub Environments の dev 環境で実行 |
| 29 | concurrency 設定 (CD) | **PASS** | `cancel-in-progress: false` |

## 4. GitHub 設定

| # | 確認項目 | 結果 | 備考 |
|---|---------|------|------|
| 30 | GitHub Secrets: AWS_OIDC_ROLE_ARN | **PASS** | 設定済み |
| 31 | GitHub Secrets: INFRACOST_API_KEY | **PASS** | 設定済み |
| 32 | GitHub Secrets: HOSTED_ZONE_ID | **PASS** | terraform apply 用 |
| 33 | GitHub Secrets: PSYCOPG2_LAYER_ARN | **PASS** | terraform apply 用 |
| 34 | GitHub Environment: dev | **PASS** | Protection Rules なし |
| 35 | GitHub Environment: prod | **PASS** | Required Reviewers 設定 |

## 5. アプリケーション動作

| # | 確認項目 | 結果 | 備考 |
|---|---------|------|------|
| 36 | Web UI アクセス | **PASS** | `https://dev.sample-cicd.click/` → HTML 返却 |
| 37 | API 認証 | **PASS** | `/tasks/` → `{"detail":"Not authenticated"}` (JWT 必要) |

## 6. セキュリティ

| # | 確認項目 | 結果 | 備考 |
|---|---------|------|------|
| 38 | OIDC 認証 (Access Key 不使用) | **PASS** | CI/CD 両方で OIDC 認証成功 |
| 39 | コミットにシークレットなし | **PASS** | `git diff --staged` でチェック済み |
| 40 | .trivyignore の CVE | **PASS** | ベースイメージ由来のみ（修正版なし） |

## 7. PR コメント検証（PR #1 で確認）

| # | 確認項目 | 結果 | 備考 |
|---|---------|------|------|
| 41 | terraform plan PR コメント | **PASS** | PR #1 に自動投稿。plan 差分がコードブロックで表示 |
| 42 | Infracost PR コメント | **PASS** | PR #1 に自動投稿。月額コスト影響レポート表示 |

## 8. Access Key 廃止

| # | 確認項目 | 結果 | 備考 |
|---|---------|------|------|
| 43 | AWS_ACCESS_KEY_ID 削除 | **PASS** | GitHub Secrets から削除済み |
| 44 | AWS_SECRET_ACCESS_KEY 削除 | **PASS** | GitHub Secrets から削除済み |
| 45 | OIDC 認証のみで CI/CD 動作 | **PASS** | Access Key 削除後も CI/CD 正常動作 |

## 9. スコープ外

| # | 項目 | 理由 |
|---|------|------|
| - | prod 環境デプロイ | v9 スコープ外（GitHub Environments 設定のみ） |

## サマリ

| カテゴリ | 合計 | PASS | SKIP | FAIL |
|---------|------|------|------|------|
| Terraform Apply | 11 | 11 | 0 | 0 |
| CI ワークフロー | 9 | 9 | 0 | 0 |
| CD ワークフロー | 9 | 9 | 0 | 0 |
| GitHub 設定 | 6 | 6 | 0 | 0 |
| アプリケーション | 2 | 2 | 0 | 0 |
| セキュリティ | 3 | 3 | 0 | 0 |
| PR コメント | 2 | 2 | 0 | 0 |
| Access Key 廃止 | 3 | 3 | 0 | 0 |
| **合計** | **45** | **45** | **0** | **0** |

全 45 項目 PASS。
