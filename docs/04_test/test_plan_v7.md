# テスト計画書 v7 — セキュリティ強化 + 認証

## 1. テスト目的

v7 で追加した以下の機能が正しく動作することを確認する。

- **JWT 認証ミドルウェア**: Cognito JWT トークンの検証、未認証リクエストの拒否
- **Graceful degradation**: `COGNITO_USER_POOL_ID` 未設定時に認証がスキップされること
- **公開エンドポイント**: `/` と `/health` が認証なしでアクセスできること

また、v6 までの既存テスト（TC-01〜TC-47, 54 件）が引き続き全件 PASS することを確認する。

---

## 2. テスト範囲

| 対象 | 内容 |
|------|------|
| `app/auth.py` | JWT 検証ロジック、Graceful degradation、JWKS キャッシュ |
| `app/routers/tasks.py` | 認証依存関数の適用確認 |
| `app/routers/attachments.py` | 認証依存関数の適用確認 |
| 既存テスト (TC-01〜TC-47) | リグレッション確認 |

> **スコープ外（手動確認対象）:**
> Cognito User Pool 動作（サインアップ / ログイン / 確認コード）、WAF、
> React SPA 認証画面は AWS へのデプロイ後に Phase 5 で手動確認する。

---

## 3. テスト環境

| 項目 | 値 |
|------|----|
| 実行環境 | ローカル / GitHub Actions |
| Python | 3.12 |
| テストフレームワーク | pytest |
| DB | SQLite in-memory（conftest.py で設定済み） |
| 認証 | テスト用: `dependency_overrides[get_current_user]` で固定値を返却 |
| AWS モック | 不要（JWT 検証はモック関数でテスト） |

### 依存パッケージ

```bash
pip install -r app/requirements.txt
pip install ruff pytest httpx "moto[sqs,events,s3]"
```

---

## 4. テストケース一覧

### 4.1 リグレッションテスト（TC-01〜TC-47）

| TC | テスト内容 | ファイル | 期待結果 |
|----|-----------|---------|---------|
| TC-01〜TC-06 | Hello World / health check | `tests/test_main.py` | PASS |
| TC-07〜TC-23 | タスク CRUD + SQS / EventBridge イベント | `tests/test_tasks.py` | PASS |
| TC-24〜TC-39 | 添付ファイル CRUD + ファイル名サニタイズ | `tests/test_attachments.py` | PASS |
| TC-40〜TC-47 | CORS + 構造化ログ + X-Ray | `tests/test_observability.py` | PASS |

> テストでは `conftest.py` で `get_current_user` をオーバーライドしているため、
> 認証有効/無効に関わらず既存テストは PASS する。

### 4.2 v7 新規テスト（TC-48〜TC-55）

#### TC-48: 認証 Graceful degradation — 環境変数未設定時は AUTH_ENABLED が False

| 項目 | 内容 |
|------|------|
| テスト対象 | `app/auth.AUTH_ENABLED` |
| 前提条件 | `COGNITO_USER_POOL_ID` と `COGNITO_APP_CLIENT_ID` が未設定 |
| 確認内容 | `AUTH_ENABLED is False` |

#### TC-49: 認証 Graceful degradation — 認証無効時に get_current_user が None を返す

| 項目 | 内容 |
|------|------|
| テスト対象 | `app/auth.get_current_user` |
| 前提条件 | `AUTH_ENABLED = False` |
| 操作 | `get_current_user(credentials=None)` を呼び出す |
| 確認内容 | 例外が発生せず `None` を返す |

#### TC-50: 認証有効時 — Bearer トークンなしで 401

| 項目 | 内容 |
|------|------|
| テスト対象 | `/tasks` エンドポイント |
| 前提条件 | 認証が有効化された状態（`get_current_user` オーバーライドを解除） |
| 操作 | `GET /tasks`（Authorization ヘッダーなし） |
| 確認内容 | レスポンス 401 |

#### TC-51: 公開エンドポイント — `/` は認証不要

| 項目 | 内容 |
|------|------|
| テスト対象 | `GET /` |
| 前提条件 | 認証が有効化された状態 |
| 操作 | `GET /`（Authorization ヘッダーなし） |
| 確認内容 | レスポンス 200、`{"message": "Hello, World!"}` |

#### TC-52: 公開エンドポイント — `/health` は認証不要

| 項目 | 内容 |
|------|------|
| テスト対象 | `GET /health` |
| 前提条件 | 認証が有効化された状態 |
| 操作 | `GET /health`（Authorization ヘッダーなし） |
| 確認内容 | レスポンス 200、`{"status": "healthy"}` |

#### TC-53: 認証有効時 — 有効なトークンで API アクセス可能

| 項目 | 内容 |
|------|------|
| テスト対象 | `/tasks` エンドポイント |
| 前提条件 | `get_current_user` がユーザー情報を返すようオーバーライド |
| 操作 | `GET /tasks` |
| 確認内容 | レスポンス 200 |

#### TC-54: JWT 検証 — 不正なトークン形式で 401

| 項目 | 内容 |
|------|------|
| テスト対象 | `app/auth._verify_token` |
| 前提条件 | `AUTH_ENABLED = True`（モック） |
| 操作 | `_verify_token("not-a-valid-jwt")` を呼び出す |
| 確認内容 | `HTTPException` (status 401, detail "Invalid token format") |

#### TC-55: JWT 検証 — kid が見つからないトークンで 401

| 項目 | 内容 |
|------|------|
| テスト対象 | `app/auth._verify_token` |
| 前提条件 | `AUTH_ENABLED = True`、JWKS キャッシュが空の鍵セット |
| 操作 | kid 付きの JWT ヘッダーを持つトークンで `_verify_token` を呼び出す |
| 確認内容 | `HTTPException` (status 401) |

---

## 5. テスト実行手順

```bash
cd /home/m-horiuchi/sample_cicd

pip install -r app/requirements.txt
pip install ruff pytest httpx "moto[sqs,events,s3]"

# lint
ruff check app/ tests/ lambda/

# 全テスト実行（既存 + v7 追加）
DATABASE_URL=sqlite:// pytest tests/ -v

# v7 テストのみ実行
DATABASE_URL=sqlite:// pytest tests/test_auth.py -v
```

---

## 6. 合格基準

| 確認項目 | 基準 |
|---------|------|
| TC-01〜TC-47（既存、54 件） | 全件 PASS |
| TC-48〜TC-55（v7 新規、8 件） | 全件 PASS |
| ruff lint | エラーなし |
| `npm run build` | ビルド成功 |

---

## 7. 手動確認項目（Phase 5 デプロイ後）

| 確認項目 | 手順 |
|---------|------|
| Cognito User Pool が作成されている | `terraform output cognito_user_pool_id` |
| WAF WebACL が作成されている | `terraform output waf_web_acl_arn` |
| Web UI にログイン画面が表示される | ブラウザで CloudFront URL にアクセス |
| サインアップ → メール確認 → ログインが動作する | Web UI からフロー実行 |
| 未認証で `/tasks` API を叩くと 401 が返る | `curl` で Authorization なしリクエスト |
| ログイン後にタスク操作が可能 | Web UI でタスク一覧・作成・編集・削除 |
| WAF レートリミットが適用されている | AWS コンソール WAF ダッシュボードで確認 |
