# API 設計書 (v2)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-03 |
| バージョン | 2.0 |
| 前バージョン | [api.md](api.md) (v1.0) |

## 変更概要

v1 の既存エンドポイント（`GET /`, `GET /health`）を維持したまま、
タスク管理 CRUD エンドポイント（5 本）を追加する。

## 1. エンドポイント一覧

### 既存（v1 から継続）

| メソッド | パス | 説明 | 対応要件 | 変更 |
|----------|------|------|----------|------|
| GET | `/` | Hello World メッセージを返す | FR-1 | なし |
| GET | `/health` | ヘルスチェック | FR-2 | なし |
| GET | `/docs` | Swagger UI（FastAPI 自動生成） | — | なし |
| GET | `/redoc` | ReDoc（FastAPI 自動生成） | — | なし |

### 新規（v2）

| メソッド | パス | 説明 | 対応要件 |
|----------|------|------|----------|
| GET | `/tasks` | タスク一覧取得 | FR-5 |
| POST | `/tasks` | タスク作成 | FR-6 |
| GET | `/tasks/{id}` | タスク個別取得 | FR-7 |
| PUT | `/tasks/{id}` | タスク更新 | FR-8 |
| DELETE | `/tasks/{id}` | タスク削除 | FR-9 |

## 2. エンドポイント詳細（既存）

v1 の [api.md](api.md) を参照。変更なし。

## 3. エンドポイント詳細（新規）

### 3.1 GET /tasks（タスク一覧取得）

登録済みの全タスクを取得する。

**リクエスト:**

```
GET /tasks HTTP/1.1
Host: <ALB DNS Name>
```

パラメータ: なし

**レスポンス（200 OK）:**

```json
[
  {
    "id": 1,
    "title": "Buy groceries",
    "description": "Milk, eggs, bread",
    "completed": false,
    "created_at": "2026-04-03T10:00:00",
    "updated_at": "2026-04-03T10:00:00"
  }
]
```

| 項目 | 値 |
|------|------|
| Status Code | 200 OK |
| Content-Type | application/json |
| レスポンス型 | `TaskResponse[]` |

### 3.2 POST /tasks（タスク作成）

新しいタスクを作成する。

**リクエスト:**

```
POST /tasks HTTP/1.1
Host: <ALB DNS Name>
Content-Type: application/json

{
  "title": "Buy groceries",
  "description": "Milk, eggs, bread"
}
```

| フィールド | 型 | 必須 | 説明 |
|------------|------|:--:|------|
| title | string | o | タスクのタイトル（1〜255 文字） |
| description | string \| null | - | タスクの説明（省略時は null） |

**レスポンス（201 Created）:**

```json
{
  "id": 1,
  "title": "Buy groceries",
  "description": "Milk, eggs, bread",
  "completed": false,
  "created_at": "2026-04-03T10:00:00",
  "updated_at": "2026-04-03T10:00:00"
}
```

| 項目 | 値 |
|------|------|
| Status Code | 201 Created |
| Content-Type | application/json |
| レスポンス型 | `TaskResponse` |

### 3.3 GET /tasks/{id}（タスク個別取得）

指定 ID のタスクを取得する。

**リクエスト:**

```
GET /tasks/1 HTTP/1.1
Host: <ALB DNS Name>
```

| パラメータ | 型 | 説明 |
|------------|------|------|
| id | int (path) | タスク ID |

**レスポンス（200 OK）:**

```json
{
  "id": 1,
  "title": "Buy groceries",
  "description": "Milk, eggs, bread",
  "completed": false,
  "created_at": "2026-04-03T10:00:00",
  "updated_at": "2026-04-03T10:00:00"
}
```

**レスポンス（404 Not Found）:**

```json
{
  "detail": "Task not found"
}
```

| 項目 | 値 |
|------|------|
| Status Code | 200 OK / 404 Not Found |
| Content-Type | application/json |

### 3.4 PUT /tasks/{id}（タスク更新）

指定 ID のタスクを更新する。リクエストボディに含まれるフィールドのみ更新する。

**リクエスト:**

```
PUT /tasks/1 HTTP/1.1
Host: <ALB DNS Name>
Content-Type: application/json

{
  "title": "Buy groceries and snacks",
  "completed": true
}
```

| パラメータ | 型 | 説明 |
|------------|------|------|
| id | int (path) | タスク ID |

| フィールド | 型 | 必須 | 説明 |
|------------|------|:--:|------|
| title | string | - | タスクのタイトル（1〜255 文字） |
| description | string \| null | - | タスクの説明 |
| completed | boolean | - | 完了フラグ |

> **注意:** 全フィールドが任意。送信されたフィールドのみ更新する（部分更新）。

**レスポンス（200 OK）:**

```json
{
  "id": 1,
  "title": "Buy groceries and snacks",
  "description": "Milk, eggs, bread",
  "completed": true,
  "created_at": "2026-04-03T10:00:00",
  "updated_at": "2026-04-03T10:30:00"
}
```

**レスポンス（404 Not Found）:**

```json
{
  "detail": "Task not found"
}
```

| 項目 | 値 |
|------|------|
| Status Code | 200 OK / 404 Not Found |
| Content-Type | application/json |

### 3.5 DELETE /tasks/{id}（タスク削除）

指定 ID のタスクを削除する。

**リクエスト:**

```
DELETE /tasks/1 HTTP/1.1
Host: <ALB DNS Name>
```

| パラメータ | 型 | 説明 |
|------------|------|------|
| id | int (path) | タスク ID |

**レスポンス（204 No Content）:**

レスポンスボディなし。

**レスポンス（404 Not Found）:**

```json
{
  "detail": "Task not found"
}
```

| 項目 | 値 |
|------|------|
| Status Code | 204 No Content / 404 Not Found |

## 4. データモデル

### 4.1 TaskCreate（リクエスト: POST）

| フィールド | 型 | 必須 | バリデーション |
|------------|------|:--:|-------------|
| title | string | o | 1〜255 文字 |
| description | string \| null | - | デフォルト null |

### 4.2 TaskUpdate（リクエスト: PUT）

| フィールド | 型 | 必須 | バリデーション |
|------------|------|:--:|-------------|
| title | string \| None | - | 1〜255 文字 |
| description | string \| None | - | — |
| completed | bool \| None | - | — |

### 4.3 TaskResponse（レスポンス）

| フィールド | 型 | 説明 |
|------------|------|------|
| id | int | タスク ID（自動採番） |
| title | string | タスクのタイトル |
| description | string \| null | タスクの説明 |
| completed | bool | 完了フラグ（デフォルト false） |
| created_at | datetime | 作成日時 |
| updated_at | datetime | 更新日時 |

## 5. 共通仕様

### 5.1 レスポンス形式

v1 と同様。すべてのレスポンスは JSON 形式、Content-Type: `application/json`。

### 5.2 エラーレスポンス

v1 の共通エラーに加え、以下のタスク固有エラーを返す。

| Status Code | 条件 | レスポンス |
|-------------|------|-----------|
| 404 Not Found | 指定 ID のタスクが存在しない | `{"detail": "Task not found"}` |
| 422 Validation Error | リクエストボディのバリデーション失敗 | FastAPI 標準形式 |

### 5.3 CORS

v1 と同様。CORS 設定は不要。

## 6. ルーティング設計

```python
# main.py
app = FastAPI()

# v1 endpoints (inline)
@app.get("/")        # FR-1
@app.get("/health")  # FR-2

# v2 endpoints (router)
app.include_router(tasks_router, prefix="/tasks", tags=["tasks"])
```

`/tasks` 配下のエンドポイントは `APIRouter` で分離し、`main.py` から `include_router` で登録する。
