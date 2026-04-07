# テスト計画書 v6 — Observability + Web UI

## 1. テスト目的

v6 で追加した以下の機能が正しく動作することを確認する。

- **CORS ミドルウェア**: 適切なオリジン制御と必要メソッドの許可
- **構造化ログ (JSONFormatter)**: CloudWatch Logs Insights に対応した JSON 形式出力
- **X-Ray graceful degradation**: `ENABLE_XRAY` 未設定時にもアプリが正常動作すること

また、v5 までの既存テスト（TC-01〜TC-39, 46 件）が引き続き全件 PASS することを確認する。

---

## 2. テスト範囲

| 対象 | 内容 |
|------|------|
| `app/main.py` | CORSMiddleware 設定、X-Ray graceful degradation |
| `app/logging_config.py` | JSONFormatter クラスの出力形式 |
| 既存テスト (TC-01〜TC-39) | リグレッション確認 |

> **スコープ外（手動確認対象）:**  
> CloudWatch Dashboard / Alarms / SNS / Web UI (React SPA) / X-Ray コンソール表示 は  
> AWS へのデプロイ後に Phase 5（デプロイ）で手動確認する。

---

## 3. テスト環境

| 項目 | 値 |
|------|----|
| 実行環境 | ローカル / GitHub Actions |
| Python | 3.11 |
| テストフレームワーク | pytest |
| DB | SQLite in-memory（conftest.py で設定済み） |
| AWS モック | 不要（本テストでは AWS サービス非呼び出し） |

### 依存パッケージ（テスト実行時に追加インストール）

```bash
pip install -r app/requirements.txt
pip install ruff pytest httpx "moto[sqs,events,s3]"
```

---

## 4. テストケース一覧

### 4.1 リグレッションテスト（TC-01〜TC-39）

| TC | テスト内容 | ファイル | 期待結果 |
|----|-----------|---------|---------|
| TC-01〜TC-06 | Hello World / health check | `tests/test_main.py` | PASS |
| TC-07〜TC-23 | タスク CRUD + SQS / EventBridge イベント | `tests/test_tasks.py` | PASS |
| TC-24〜TC-39 | 添付ファイル CRUD + ファイル名サニタイズ（23 件） | `tests/test_attachments.py` | PASS |

> v6 追加の `CORS_ALLOWED_ORIGINS`・`ENABLE_XRAY` はデフォルト未設定のため、既存テストへの影響なし。

### 4.2 v6 新規テスト（TC-40〜TC-47）

#### TC-40: CORS — preflight OPTIONS リクエストに CORS ヘッダーが返る

| 項目 | 内容 |
|------|------|
| テスト対象 | `app/main.py` の `CORSMiddleware` 設定 |
| 前提条件 | `CORS_ALLOWED_ORIGINS` 未設定（デフォルト `*`） |
| 操作 | `OPTIONS /tasks`、ヘッダー `Origin: http://localhost:3000`、`Access-Control-Request-Method: GET` |
| 確認内容 | レスポンス 200、`access-control-allow-origin` ヘッダーが存在する |

#### TC-41: CORS — GET リクエストに Access-Control-Allow-Origin が付与される

| 項目 | 内容 |
|------|------|
| テスト対象 | `app/main.py` の `CORSMiddleware` 設定 |
| 操作 | `GET /`、ヘッダー `Origin: http://localhost:3000` |
| 確認内容 | レスポンス 200、`access-control-allow-origin` ヘッダーが存在する |

#### TC-42: CORS — 必要なメソッド（GET/POST/PUT/DELETE）が許可されている

| 項目 | 内容 |
|------|------|
| テスト対象 | `app/main.py` の `CORSMiddleware` 設定 |
| 操作 | `OPTIONS /tasks`、`Access-Control-Request-Method: DELETE` |
| 確認内容 | レスポンス 200、`access-control-allow-methods` に GET / POST / PUT / DELETE が含まれる |

#### TC-43: 構造化ログ — JSONFormatter が有効な JSON を出力する

| 項目 | 内容 |
|------|------|
| テスト対象 | `app/logging_config.JSONFormatter` |
| 操作 | `logging.LogRecord` を生成し `format()` を呼び出す |
| 確認内容 | 出力が JSON パース可能、`level == "INFO"`、`logger == "test.logger"`、`message == "Test message"`、`timestamp` キーが存在する |

#### TC-44: 構造化ログ — 例外情報が JSON に含まれる

| 項目 | 内容 |
|------|------|
| テスト対象 | `app/logging_config.JSONFormatter` |
| 操作 | `exc_info` 付きの `LogRecord` を生成し `format()` を呼び出す |
| 確認内容 | JSON に `exception` キーが存在し、`"ValueError"` が含まれる |

#### TC-45: 構造化ログ — 必須フィールドがすべて存在する

| 項目 | 内容 |
|------|------|
| テスト対象 | `app/logging_config.JSONFormatter` |
| 操作 | `WARNING` レベルの `LogRecord` を生成し `format()` を呼び出す |
| 確認内容 | JSON に `timestamp`、`level`、`logger`、`message` キーがすべて存在する |

#### TC-46: X-Ray graceful degradation — デフォルトで無効

| 項目 | 内容 |
|------|------|
| テスト対象 | `app/main.ENABLE_XRAY` |
| 前提条件 | `ENABLE_XRAY` 環境変数が未設定 |
| 確認内容 | `ENABLE_XRAY is False` |

#### TC-47: X-Ray graceful degradation — X-Ray なしでもアプリが正常動作

| 項目 | 内容 |
|------|------|
| テスト対象 | `GET /health` エンドポイント（X-Ray 無効状態） |
| 前提条件 | `ENABLE_XRAY` 環境変数が未設定 |
| 操作 | `GET /health` |
| 確認内容 | レスポンス 200、`{"status": "healthy"}` |

---

## 5. テスト実行手順

```bash
# プロジェクトルートから実行
cd /home/m-horiuchi/sample_cicd

# 依存インストール
pip install -r app/requirements.txt
pip install ruff pytest httpx "moto[sqs,events,s3]"

# lint
ruff check app/ tests/ lambda/

# 全テスト実行（既存 + v6 追加）
DATABASE_URL=sqlite:// pytest tests/ -v

# v6 テストのみ実行
DATABASE_URL=sqlite:// pytest tests/test_observability.py -v
```

---

## 6. 合格基準

| 確認項目 | 基準 |
|---------|------|
| TC-01〜TC-39（既存、46 件） | 全件 PASS |
| TC-40〜TC-47（v6 新規、8 件） | 全件 PASS |
| ruff lint | エラーなし |
| `npm run build` | ビルド成功 |
| `terraform validate` | OK（Phase 3 確認済み） |

---

## 7. 手動確認項目（Phase 5 デプロイ後）

以下は AWS 環境へのデプロイ後に確認する項目。本テスト計画の合格基準には含まれない。

| 確認項目 | 手順 |
|---------|------|
| ECS ログが JSON 形式で出力されている | CloudWatch Logs Insights で `parse @message` クエリ実行 |
| X-Ray コンソールでトレースが表示される | X-Ray > Service Map でリクエストパスを確認 |
| CloudWatch Dashboard にメトリクスが表示される | ALB / ECS / RDS / Lambda / SQS の各ウィジェット確認 |
| CloudWatch Alarms が OK 状態 | 大部分のアラームが OK（低負荷環境のため） |
| Web UI (CloudFront URL) にアクセスできる | ブラウザでタスク一覧・作成・編集・削除・完了切替を操作 |
| 添付ファイル操作が Web UI から動作する | アップロード・ダウンロード・削除を操作 |
| CI/CD でフロントエンドのビルド・デプロイが成功する | GitHub Actions のログ確認 |
