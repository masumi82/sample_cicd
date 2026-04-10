# テスト計画書 (v12)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-10 |
| バージョン | 12.0 |
| 前バージョン | [test_plan_v11.md](test_plan_v11.md) (v11.0) |

## 変更概要

v12 ではアプリケーション層の読み書き分離を実装したため、以下のテストを新規追加する:

- **読み書き分離テスト**: `app/database.py` の `get_read_db()` と読み取りルーティング
- **Graceful degradation テスト**: Read Replica 未設定時のフォールバック動作
- **URL 構築テスト**: `_build_read_database_url()` の環境変数パターン

> インフラ（AWS Backup, RDS Read Replica, S3 CRR, Lifecycle）は Terraform で管理。テストは Phase 5 の動作確認で検証。

## 1. テスト方針

### 1.1 テスト範囲

| テスト種別 | 対象 | ツール |
|-----------|------|--------|
| 読み書き分離テスト | `app/database.py` + `app/routers/tasks.py` | pytest + 別 SQLite エンジン |
| Graceful degradation | Read Replica 未設定時の動作 | pytest + 共有セッション |
| URL 構築テスト | `_build_read_database_url()` | pytest + `unittest.mock.patch` |

### 1.2 テスト環境

- DB: SQLite in-memory（既存 conftest.py + 読み書き分離用の別エンジン）
- Redis: `fakeredis`（既存）
- AWS: `moto`（既存）

### 1.3 テスト設計方針

読み書き分離の検証には、**書き込み用と読み取り用で別の SQLite エンジン**を使用する。書き込み先のデータが読み取り側から見えないことで、ルーティングが正しく分離されていることを証明する。

## 2. テストケース一覧

### 2.1 読み書き分離テスト（ReadWriteSplit）

| TC | テスト名 | 概要 |
|----|---------|------|
| TC-85 | `test_list_tasks_uses_read_db` | `GET /tasks` が読み取りセッションを使用する（書き込みDBのデータが見えない） |
| TC-86 | `test_get_task_uses_read_db` | `GET /tasks/{id}` が読み取りセッションを使用する |
| TC-87 | `test_create_task_uses_write_db` | `POST /tasks` が書き込みセッションを使用する |
| TC-88 | `test_update_task_uses_write_db` | `PUT /tasks/{id}` が書き込みセッションを使用する |
| TC-89 | `test_delete_task_uses_write_db` | `DELETE /tasks/{id}` が書き込みセッションを使用する |

### 2.2 Graceful degradation テスト

| TC | テスト名 | 概要 |
|----|---------|------|
| TC-90 | `test_shared_session_reads_work` | 読み書き同一セッション時に `GET /tasks` が書き込みデータを返す |
| TC-91 | `test_shared_session_get_by_id_works` | 読み書き同一セッション時に `GET /tasks/{id}` が正常動作する |

### 2.3 URL 構築テスト（BuildReadUrl）

| TC | テスト名 | 概要 |
|----|---------|------|
| TC-92 | `test_database_read_url_env` | `DATABASE_READ_URL` 設定時にその値が返される |
| TC-93 | `test_db_read_host_env` | `DB_READ_HOST` 設定時に `DB_*` 変数から URL が構築される |
| TC-94 | `test_no_read_config_returns_none` | 未設定時に `None` が返される（Graceful degradation） |

## 3. テスト実行

```bash
# 全テスト実行
DATABASE_URL=sqlite:// pytest tests/ -v

# 読み書き分離テストのみ
DATABASE_URL=sqlite:// pytest tests/test_db_routing.py -v
```

## 4. 想定テスト件数

| ファイル | v11 | v12 | 増減 |
|---------|-----|-----|------|
| test_main.py | 6 | 6 | - |
| test_tasks.py | 17 | 17 | - |
| test_attachments.py | 23 | 23 | - |
| test_observability.py | 8 | 8 | - |
| test_auth.py | 8 | 8 | - |
| test_cache.py | 22 | 22 | - |
| **test_db_routing.py** | - | **10** | **+10** |
| **合計** | **84** | **94** | **+10** |

## 5. テスト結果

```
============================== 94 passed in 2.26s ==============================
```

全 94 テストがパス。既存 84 テストの回帰なし。
