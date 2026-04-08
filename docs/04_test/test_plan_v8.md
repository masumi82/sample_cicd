# テスト計画書 v8 — HTTPS + カスタムドメイン + Remote State

## 1. テスト目的

v8 ではアプリケーションコード（`app/`、`lambda/`、`frontend/src/`）に変更がないため、
新規 Python テストの追加は不要。以下を確認する。

- **リグレッション**: v7 までの既存テスト（TC-01〜TC-55, 62 件）が引き続き全件 PASS すること
- **Terraform validate**: `infra/` および `infra/bootstrap/` の構文が正しいこと
- **フロントエンドビルド**: `npm run build` が成功すること
- **Lint**: `ruff check` が PASS すること

インフラ変更（ACM 証明書、Route 53、CloudFront カスタムドメイン、Remote State）は
Phase 5（デプロイ）で実環境テストを行う。

---

## 2. テスト範囲

| 対象 | 内容 |
|------|------|
| 既存テスト (TC-01〜TC-55, 62 件) | リグレッション確認 |
| `infra/*.tf` | `terraform validate` で構文検証 |
| `infra/bootstrap/*.tf` | `terraform validate` で構文検証 |
| `frontend/` | `npm run build` でビルド検証 |
| `app/`, `tests/`, `lambda/` | `ruff check` で Lint 検証 |

> **スコープ外（Phase 5 で確認）:**
> ACM 証明書の DNS 検証、CloudFront カスタムドメイン適用、Route 53 ALIAS レコード、
> Remote State の S3/DynamoDB 作成、`terraform init -migrate-state` による state 移行、
> `https://dev.sample-cicd.click` でのアクセス確認。

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

v8 ではアプリケーションコードに変更がないため、既存テストがすべて PASS すれば十分。

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
| V-02 | `infra/bootstrap/` | `cd infra/bootstrap && terraform init -backend=false && terraform validate` | `Success! The configuration is valid.` |

### 4.3 Lint + Build

| # | 対象 | コマンド | 期待結果 |
|---|------|---------|---------|
| L-01 | Python lint | `ruff check app/ tests/ lambda/` | `All checks passed!` |
| B-01 | Frontend build | `cd frontend && npm ci && npm run build` | `✓ built` |

### 4.4 変数廃止の確認

| # | 確認内容 | コマンド | 期待結果 |
|---|---------|---------|---------|
| D-01 | `enable_https` の残存なし | `grep -rn "enable_https" infra/ --include="*.tf" --include="*.tfvars"` | 出力なし |
| D-02 | `var.domain_name` の残存なし | `grep -rn 'var\.domain_name' infra/ --include="*.tf"` | 出力なし |
| D-03 | `https.tf` が削除済み | `test -f infra/https.tf` | ファイルが存在しない |

---

## 5. テスト実行結果

| # | テスト | 結果 | 備考 |
|---|--------|------|------|
| 1 | リグレッション（62 件） | PASS | 62 passed in 2.20s |
| V-01 | terraform validate (infra/) | PASS | Success |
| V-02 | terraform validate (bootstrap/) | PASS | Success |
| L-01 | ruff check | PASS | All checks passed |
| B-01 | npm run build | PASS | ✓ built |
| D-01 | enable_https 残存なし | PASS | 出力なし |
| D-02 | var.domain_name 残存なし | PASS | 出力なし |
| D-03 | https.tf 削除済み | PASS | ファイルなし |

---

## 6. 合格基準

- [x] 既存テスト 62 件が全件 PASS
- [x] Terraform validate が infra/ と bootstrap/ の両方で成功
- [x] ruff check が PASS
- [x] フロントエンドビルドが成功
- [x] `enable_https` / `domain_name` の旧変数が完全に削除されていること
