# テスト計画書 v9 — CI/CD 完全自動化 + セキュリティスキャン

## 1. テスト目的

v9 ではアプリケーションコード（`app/`、`lambda/`、`frontend/src/`）に変更がないため、
新規 Python テストの追加は不要。以下を確認する。

- **リグレッション**: v8 までの既存テスト（TC-01〜TC-55, 62 件）が引き続き全件 PASS すること
- **Terraform validate**: `infra/` の構文が正しいこと（v9 新規リソース含む）
- **フロントエンドビルド**: `npm run build` が成功すること
- **Lint**: `ruff check` が PASS すること
- **旧リソース参照の排除**: `aws_lb_target_group.app` への参照が残っていないこと
- **ワークフロー分割**: `ci.yml` と `cd.yml` が存在すること

インフラ変更（CodeDeploy B/G, OIDC, Trivy/tfsec スキャン, Terraform CI/CD, Infracost）は
Phase 5（デプロイ）で実環境テストを行う。

---

## 2. テスト範囲

| 対象 | 内容 |
|------|------|
| 既存テスト (TC-01〜TC-55, 62 件) | リグレッション確認 |
| `infra/*.tf` | `terraform validate` で構文検証（codedeploy.tf, oidc.tf 含む） |
| `frontend/` | `npm run build` でビルド検証 |
| `app/`, `tests/`, `lambda/` | `ruff check` で Lint 検証 |

> **スコープ外（Phase 5 で確認）:**
> CodeDeploy B/G デプロイ動作、OIDC 認証による GitHub Actions → AWS 接続、
> Trivy コンテナスキャン結果、tfsec セキュリティスキャン結果、
> terraform plan の PR コメント出力、Infracost コスト影響の PR コメント出力、
> GitHub Environments の承認ゲート設定。

---

## 3. テスト環境

| 項目 | 値 |
|------|----|
| 実行環境 | ローカル / GitHub Actions |
| Python | 3.12 |
| テストフレームワーク | pytest |
| DB | SQLite in-memory（conftest.py で設定済み） |
| 認証 | テスト用: `dependency_overrides[get_current_user]` で固定値（v7 と同じ） |
| AWS モック | moto（SQS, EventBridge, S3）— v4〜v5 と同じ |

---

## 4. テストケース

### 4.1 リグレッションテスト（既存 62 件）

v9 ではアプリケーションコードに変更がないため、既存テストがすべて PASS すれば十分。

| ファイル | テスト数 | 対象バージョン |
|---------|---------|-------------|
| `tests/test_main.py` | 6 | v1 |
| `tests/test_tasks.py` | 17 | v2 + v4 |
| `tests/test_attachments.py` | 23 | v5 |
| `tests/test_observability.py` | 8 | v6 |
| `tests/test_auth.py` | 8 | v7 |
| **合計** | **62** | |

### 4.2 Terraform validate

| # | 対象 | コマンド | 期待結果 |
|---|------|---------|---------|
| V-01 | `infra/` | `cd infra && terraform validate` | `Success! The configuration is valid.` |

### 4.3 Lint + Build

| # | 対象 | コマンド | 期待結果 |
|---|------|---------|---------|
| L-01 | Python lint | `ruff check app/ tests/ lambda/` | `All checks passed!` |
| B-01 | Frontend build | `cd frontend && npm ci && npm run build` | `✓ built` |

### 4.4 v9 固有の確認

| # | 確認内容 | コマンド | 期待結果 |
|---|---------|---------|---------|
| V9-01 | 旧 TG 参照の排除 | `grep -rn "aws_lb_target_group\.app" infra/ --include="*.tf"` | 出力なし |
| V9-02 | ci.yml が存在 | `test -f .github/workflows/ci.yml` | 存在する |
| V9-03 | cd.yml が存在 | `test -f .github/workflows/cd.yml` | 存在する |
| V9-04 | codedeploy.tf が存在 | `test -f infra/codedeploy.tf` | 存在する |
| V9-05 | oidc.tf が存在 | `test -f infra/oidc.tf` | 存在する |
| V9-06 | Blue TG が定義 | `grep "aws_lb_target_group.*blue" infra/alb.tf` | ヒットする |
| V9-07 | Green TG が定義 | `grep "aws_lb_target_group.*green" infra/alb.tf` | ヒットする |
| V9-08 | deployment_controller = CODE_DEPLOY | `grep "CODE_DEPLOY" infra/ecs.tf` | ヒットする |

---

## 5. テスト実行結果

| # | テスト | 結果 | 備考 |
|---|--------|------|------|
| 1 | リグレッション（62 件） | **PASS** | 62 passed in 1.88s |
| V-01 | terraform validate (infra/) | **PASS** | Success! The configuration is valid. |
| L-01 | ruff check | **PASS** | All checks passed! |
| B-01 | npm run build | **PASS** | ✓ built in 1.78s |
| V9-01 | 旧 TG 参照なし | **PASS** | 出力なし |
| V9-02 | ci.yml 存在 | **PASS** | |
| V9-03 | cd.yml 存在 | **PASS** | |
| V9-04 | codedeploy.tf 存在 | **PASS** | |
| V9-05 | oidc.tf 存在 | **PASS** | |
| V9-06 | Blue TG 定義 | **PASS** | |
| V9-07 | Green TG 定義 | **PASS** | |
| V9-08 | CODE_DEPLOY 設定 | **PASS** | |

---

## 6. 合格基準

- [x] 既存テスト 62 件が全件 PASS
- [x] Terraform validate が成功
- [x] ruff check が PASS
- [x] フロントエンドビルドが成功
- [x] 旧 `aws_lb_target_group.app` 参照が完全に排除されていること
- [x] v9 新規ファイル（codedeploy.tf, oidc.tf, ci.yml, cd.yml）が存在すること
- [x] Blue/Green TG + CODE_DEPLOY deployment_controller が設定されていること

---

## 7. 備考

- `ci-cd.yml`（旧ワークフロー）はまだ残存している。Phase 5（デプロイ）時に削除する
  （新ワークフロー ci.yml + cd.yml の動作確認後に削除する方が安全）
- v9 はアプリケーションコード変更なしのため、新規テストコードは不要
- CI/CD パイプラインの実動作テスト（Trivy, tfsec, terraform plan, Infracost, CodeDeploy B/G）は
  Phase 5 の動作確認で実施する
