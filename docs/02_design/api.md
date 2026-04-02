# API 設計書

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-02 |
| バージョン | 1.0 |

## 1. エンドポイント一覧

| メソッド | パス | 説明 | 対応要件 |
|----------|------|------|----------|
| GET | `/` | Hello World メッセージを返す | FR-1 |
| GET | `/health` | ヘルスチェック | FR-2 |
| GET | `/docs` | Swagger UI（FastAPI 自動生成） | — |
| GET | `/redoc` | ReDoc（FastAPI 自動生成） | — |

## 2. エンドポイント詳細

### 2.1 GET /

ルートエンドポイント。Hello World メッセージを返す。

**リクエスト:**

```
GET / HTTP/1.1
Host: <ALB DNS Name>
```

パラメータ: なし

**レスポンス:**

```json
{
  "message": "Hello, World!"
}
```

| 項目 | 値 |
|------|------|
| Status Code | 200 OK |
| Content-Type | application/json |

### 2.2 GET /health

ALB ターゲットグループのヘルスチェック用エンドポイント。

**リクエスト:**

```
GET /health HTTP/1.1
Host: <ALB DNS Name>
```

パラメータ: なし

**レスポンス:**

```json
{
  "status": "healthy"
}
```

| 項目 | 値 |
|------|------|
| Status Code | 200 OK |
| Content-Type | application/json |

### 2.3 GET /docs

FastAPI が自動生成する Swagger UI ドキュメント。
ブラウザでアクセスすると、インタラクティブな API ドキュメントが表示される。

### 2.4 GET /redoc

FastAPI が自動生成する ReDoc ドキュメント。
Swagger UI の代替として、読みやすいドキュメントを提供する。

## 3. 共通仕様

### 3.1 レスポンス形式

- すべてのレスポンスは JSON 形式
- Content-Type: `application/json`
- 文字エンコーディング: UTF-8

### 3.2 エラーレスポンス

FastAPI のデフォルトエラーハンドリングに準拠する。

**404 Not Found:**

```json
{
  "detail": "Not Found"
}
```

**422 Validation Error:**

```json
{
  "detail": [
    {
      "loc": ["query", "param_name"],
      "msg": "error message",
      "type": "error_type"
    }
  ]
}
```

**500 Internal Server Error:**

```json
{
  "detail": "Internal Server Error"
}
```

### 3.3 CORS

本プロジェクトでは CORS 設定は不要（API は ALB 経由のサーバーサイドアクセスのみを想定）。

## 4. アプリケーション設計

### 4.1 ファイル構成

```
app/
├── main.py           # FastAPI アプリケーションエントリーポイント
├── requirements.txt  # Python 依存パッケージ
└── Dockerfile        # コンテナイメージ定義
```

### 4.2 main.py 設計

```python
# Endpoints:
# - GET /         → {"message": "Hello, World!"}
# - GET /health   → {"status": "healthy"}
#
# Server: uvicorn, host=0.0.0.0, port=8000
```

### 4.3 依存パッケージ

| パッケージ | 用途 |
|------------|------|
| fastapi | Web フレームワーク |
| uvicorn[standard] | ASGI サーバー |

### 4.4 ポート設定

| 項目 | 値 |
|------|------|
| アプリケーションポート | 8000 |
| ALB リスナーポート | 80 |
| プロトコル | HTTP |
