# テスト計画書 v4 — イベント駆動アーキテクチャ

## 1. テスト目的

v4 で追加したイベント発行機能（SQS / EventBridge）が正しく動作することを確認する。
また、v3 までの既存テスト（TC-01〜TC-18）が引き続き全件 PASS することを確認する。

---

## 2. テスト範囲

| 対象 | 内容 |
|------|------|
| `app/services/events.py` | SQS / EventBridge 送信ロジック |
| `app/routers/tasks.py` | タスク作成・完了時のイベント発行呼び出し |
| 既存テスト (TC-01〜TC-18) | リグレッション確認 |

---

## 3. テスト環境

| 項目 | 値 |
|------|----|
| 実行環境 | ローカル / GitHub Actions |
| Python | 3.12 |
| テストフレームワーク | pytest |
| DB | SQLite in-memory（conftest.py で設定済み） |
| AWS モック | moto 5.x（`mock_aws`）+ `unittest.mock.patch` |

### 依存パッケージ（テスト実行時に追加インストール）

```bash
pip install -r app/requirements.txt
pip install ruff pytest httpx moto[sqs,events]
```

### AWS 認証情報（moto 使用時）

moto は実際の AWS 接続を行わないため、ダミー認証情報を環境変数でセットする。
`aws_credentials` pytest fixture（conftest または各テストファイルで定義）にて設定する。

---

## 4. テストケース一覧

### 4.1 リグレッションテスト（TC-01〜TC-18）

| TC | テスト内容 | ファイル | 期待結果 |
|----|-----------|---------|---------|
| TC-01〜TC-06 | Hello World / health check | `tests/test_main.py` | PASS |
| TC-07〜TC-18 | タスク CRUD 全件 | `tests/test_tasks.py` | PASS |

> v4 追加後も SQS_QUEUE_URL / EVENTBRIDGE_BUS_NAME が未設定であれば `publish_*` は
> 即 return するため、既存テストへの影響はない。

### 4.2 v4 新規テスト（TC-19〜TC-23）

#### TC-19: タスク作成時に SQS メッセージが送信される

| 項目 | 内容 |
|------|------|
| テスト対象 | `POST /tasks` |
| 前提条件 | `SQS_QUEUE_URL` 環境変数をモックキュー URL にセット |
| モック手法 | `moto mock_aws` — boto3 の SQS 呼び出しを moto が代替 |
| 操作 | `POST /tasks {"title": "SQS test task"}` |
| 確認内容 | レスポンス 201、SQS キューに `event=task_created` のメッセージが 1 件入っている |
| 確認項目 | `body["event"] == "task_created"`, `body["title"]`, `body["task_id"]` が正しいこと |

#### TC-20: タスク完了時に EventBridge イベントが送信される

| 項目 | 内容 |
|------|------|
| テスト対象 | `PUT /tasks/{id}` （completed: false → true） |
| 前提条件 | `EVENTBRIDGE_BUS_NAME` 環境変数をセット |
| モック手法 | `unittest.mock.patch("app.services.events._events_client")` |
| 操作 | タスク作成後、`PUT /tasks/{id} {"completed": true}` |
| 確認内容 | レスポンス 200、`put_events` が 1 回呼び出された |
| 確認項目 | `DetailType == "TaskCompleted"`, `EventBusName` が正しいこと、`Detail` 内の `task_id` と `title` が一致すること |

> EventBridge は "イベントを受信する" API を持たないため、moto の SQS と異なり
> `mock.patch` で送信呼び出しを検証する方式を採用した。

#### TC-21: 完了済みタスクの再完了で EventBridge イベントは送信されない

| 項目 | 内容 |
|------|------|
| テスト対象 | `PUT /tasks/{id}` （completed: true → true） |
| 前提条件 | 同上 |
| モック手法 | `unittest.mock.patch` で `put_events` 呼び出し回数を計測 |
| 操作 | 1 回目 `PUT completed=true`（イベント発行）→ 2 回目 `PUT completed=true` |
| 確認内容 | `put_events` の呼び出し回数が合計 1 回（重複なし） |

#### TC-22: SQS_QUEUE_URL 未設定時はタスク作成がエラーにならない

| 項目 | 内容 |
|------|------|
| テスト対象 | `POST /tasks` |
| 前提条件 | `SQS_QUEUE_URL` 環境変数が未設定 |
| 確認内容 | レスポンス 201（イベント発行をスキップしてもタスクは正常作成） |

#### TC-23: EVENTBRIDGE_BUS_NAME 未設定時はタスク完了がエラーにならない

| 項目 | 内容 |
|------|------|
| テスト対象 | `PUT /tasks/{id}` |
| 前提条件 | `EVENTBRIDGE_BUS_NAME` 環境変数が未設定 |
| 確認内容 | レスポンス 200（イベント発行をスキップしてもタスクは正常更新） |

---

## 5. テスト実行手順

```bash
# プロジェクトルートから実行
cd /home/m-horiuchi/sample_cicd

# 依存インストール
pip install -r app/requirements.txt
pip install ruff pytest httpx moto[sqs,events]

# lint
ruff check app/ tests/ lambda/

# 全テスト実行（既存 + v4 追加）
DATABASE_URL=sqlite:// pytest tests/ -v

# v4 テストのみ実行
DATABASE_URL=sqlite:// pytest tests/test_tasks.py -k "tc_19 or tc_20 or tc_21 or tc_22 or tc_23" -v
# または番号なし名称で
DATABASE_URL=sqlite:// pytest tests/test_tasks.py -k "sqs or eventbridge or without_sqs or without_eventbridge or duplicate" -v
```

---

## 6. 合格基準

| 確認項目 | 基準 |
|---------|------|
| TC-01〜TC-18（既存） | 全件 PASS |
| TC-19〜TC-23（v4 新規） | 全件 PASS |
| ruff lint | エラーなし |
| `terraform validate` | OK（実装フェーズ確認済み） |
