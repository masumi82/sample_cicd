# テスト計画書 (v2)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-03 |
| バージョン | 2.0 |
| 前バージョン | [test_plan.md](test_plan.md) (v1.0) |

## 変更概要

v1 のテスト（TC-01〜TC-06）を維持したまま、タスク CRUD API のテスト（TC-07〜TC-18）を追加する。
テスト用 DB には SQLite インメモリを使用し、外部依存なしで CI 実行可能とする。

## 1. テスト方針

### 1.1 テスト種別

| 種別 | 対象 | ツール | v2 変更 |
|------|------|--------|---------|
| ユニットテスト | FastAPI エンドポイント | pytest + FastAPI TestClient | タスク CRUD テスト追加 |
| Lint チェック | app/, tests/ | ruff | なし |
| ビルド検証 | Docker イメージ | docker build | コンテキスト変更 |

### 1.2 テスト範囲

v1 のエンドポイントテストに加え、タスク CRUD API の全エンドポイントをテストする。

### 1.3 テスト用データベース

| 環境 | DB | 理由 |
|------|------|------|
| テスト | SQLite インメモリ (`sqlite://`) | 外部依存なし、高速、CI 対応 |
| 本番 | PostgreSQL (RDS) | データ永続化 |

> **設計判断:** PostgreSQL 固有機能を使用しないため、SQLite での互換テストで十分。

### 1.4 テストフレームワーク

| パッケージ | 用途 | v2 変更 |
|------------|------|---------|
| pytest | テストランナー | なし |
| httpx | FastAPI TestClient の依存 | なし |
| ruff | Lint チェック | なし |

## 2. テスト対象

### 既存（v1）

| 対象 | ファイル | 対応要件 |
|------|---------|----------|
| GET / | app/main.py | FR-1 |
| GET /health | app/main.py | FR-2 |

### 新規（v2）

| 対象 | ファイル | 対応要件 |
|------|---------|----------|
| GET /tasks | app/routers/tasks.py | FR-5 |
| POST /tasks | app/routers/tasks.py | FR-6 |
| GET /tasks/{id} | app/routers/tasks.py | FR-7 |
| PUT /tasks/{id} | app/routers/tasks.py | FR-8 |
| DELETE /tasks/{id} | app/routers/tasks.py | FR-9 |

## 3. テストケース一覧

### 既存（v1: TC-01〜TC-06）— 変更なし

| ID | エンドポイント | テスト内容 | 期待結果 | 対応要件 |
|----|--------------|-----------|---------|----------|
| TC-01 | GET / | 正常リクエスト | 200, `{"message": "Hello, World!"}` | FR-1 |
| TC-02 | GET / | Content-Type 確認 | `application/json` | FR-1 |
| TC-03 | GET /health | 正常リクエスト | 200, `{"status": "healthy"}` | FR-2 |
| TC-04 | GET /health | Content-Type 確認 | `application/json` | FR-2 |
| TC-05 | GET /notfound | 存在しないパス | 404 | — |
| TC-06 | POST / | 許可されていないメソッド | 405 | — |

### 新規（v2: TC-07〜TC-18）

| ID | エンドポイント | テスト内容 | 期待結果 | 対応要件 |
|----|--------------|-----------|---------|----------|
| TC-07 | GET /tasks | 空リスト取得 | 200, `[]` | FR-5 |
| TC-08 | POST /tasks | タスク作成（title + description） | 201, 作成されたタスク | FR-6 |
| TC-09 | POST /tasks | タスク作成（title のみ、description 省略） | 201, description=null | FR-6 |
| TC-10 | POST /tasks | バリデーションエラー（title 空文字） | 422 | FR-6 |
| TC-11 | GET /tasks | タスク作成後の一覧取得 | 200, 1件のタスク | FR-5 |
| TC-12 | GET /tasks/{id} | 存在するタスクの取得 | 200, タスク詳細 | FR-7 |
| TC-13 | GET /tasks/{id} | 存在しないタスクの取得 | 404, `{"detail": "Task not found"}` | FR-7 |
| TC-14 | PUT /tasks/{id} | タスク更新（title 変更） | 200, 更新後のタスク | FR-8 |
| TC-15 | PUT /tasks/{id} | タスク更新（completed を true に） | 200, completed=true | FR-8 |
| TC-16 | PUT /tasks/{id} | 存在しないタスクの更新 | 404, `{"detail": "Task not found"}` | FR-8 |
| TC-17 | DELETE /tasks/{id} | タスク削除 | 204, レスポンスボディなし | FR-9 |
| TC-18 | DELETE /tasks/{id} | 存在しないタスクの削除 | 404, `{"detail": "Task not found"}` | FR-9 |

## 4. テストファイル構成

```
tests/
├── __init__.py        # パッケージ初期化（空ファイル）
├── conftest.py        # テスト用 DB 設定（SQLite インメモリ、get_db オーバーライド）
├── test_main.py       # v1 エンドポイントテスト (TC-01〜TC-06)
└── test_tasks.py      # v2 タスク CRUD テスト (TC-07〜TC-18)
```

### 4.1 conftest.py の設計

```python
# 1. SQLite インメモリエンジン作成
# 2. テスト用セッション作成
# 3. get_db 依存関数をオーバーライド
# 4. 各テスト前にテーブル作成、テスト後に削除（テスト間の独立性確保）
# 5. TestClient を fixture として提供
```

## 5. テスト実行方法

### 5.1 ローカル実行

```bash
# 依存パッケージのインストール
pip install -r app/requirements.txt
pip install ruff pytest httpx

# 全テスト実行
pytest tests/ -v

# v2 テストのみ実行
pytest tests/test_tasks.py -v

# Lint チェック
ruff check app/ tests/
```

### 5.2 CI 実行（GitHub Actions）

v1 と同じワークフロー。`pytest tests/ -v` で全 18 テストが自動実行される。
SQLite インメモリを使用するため、CI 環境への追加依存は不要。

## 6. 合格基準

| 基準 | 条件 |
|------|------|
| テスト合格 | 全テストケース（TC-01 〜 TC-18）が PASS |
| Lint 合格 | `ruff check` がエラー 0 件 |
| カバレッジ | 本プロジェクトではカバレッジ閾値は設けない（学習用） |
