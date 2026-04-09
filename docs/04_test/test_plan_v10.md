# テスト計画書 (v10)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-08 |
| バージョン | 10.0 |
| 前バージョン | [test_plan_v9.md](test_plan_v9.md) (v9.0) |

## 変更概要

v10 ではアプリケーションレベルの Redis キャッシュを追加したため、以下のテストを新規追加する:

- **キャッシュサービステスト**: `app/services/cache.py` の単体テスト
- **キャッシュ統合テスト**: `app/routers/tasks.py` のキャッシュ統合動作テスト
- **Graceful degradation テスト**: Redis 未設定・接続失敗時のフォールバック

> インフラ（API Gateway, ElastiCache）は Terraform で管理。テストは Phase 5 の動作確認で検証。

## 1. テスト方針

### 1.1 テスト範囲

| テスト種別 | 対象 | ツール |
|-----------|------|--------|
| 単体テスト | `app/services/cache.py` | pytest + `unittest.mock` |
| 統合テスト | `app/routers/tasks.py` キャッシュ統合 | pytest + `fakeredis` + `unittest.mock` |
| Graceful degradation | キャッシュなし動作 | pytest + `unittest.mock` |

### 1.2 テスト環境

- DB: SQLite in-memory（既存 conftest.py）
- Redis: `fakeredis` または `unittest.mock.patch`
- AWS: `moto`（既存）

## 2. テストケース一覧

### 2.1 キャッシュサービス単体テスト

| TC | テスト名 | 概要 |
|----|---------|------|
| TC-63 | `test_cache_get_returns_none_without_redis` | REDIS_URL 未設定時に `cache_get` が None を返す |
| TC-64 | `test_cache_set_does_nothing_without_redis` | REDIS_URL 未設定時に `cache_set` がエラーなく終了 |
| TC-65 | `test_cache_delete_does_nothing_without_redis` | REDIS_URL 未設定時に `cache_delete` がエラーなく終了 |
| TC-66 | `test_cache_get_hit` | Redis にデータがある場合にキャッシュヒット |
| TC-67 | `test_cache_get_miss` | Redis にデータがない場合に None を返す |
| TC-68 | `test_cache_set_with_ttl` | TTL 付きでデータが保存される |
| TC-69 | `test_cache_delete_removes_keys` | 指定キーが削除される |
| TC-70 | `test_cache_get_returns_none_on_error` | Redis エラー時に None を返す（例外は飲み込む） |
| TC-71 | `test_cache_set_silently_fails_on_error` | Redis エラー時にサイレント失敗 |
| TC-72 | `test_cache_delete_silently_fails_on_error` | Redis エラー時にサイレント失敗 |

### 2.2 タスク CRUD キャッシュ統合テスト

| TC | テスト名 | 概要 |
|----|---------|------|
| TC-73 | `test_list_tasks_uses_cache` | GET /tasks がキャッシュヒット時に DB を呼ばない |
| TC-74 | `test_list_tasks_populates_cache_on_miss` | GET /tasks がキャッシュミス時に DB から取得しキャッシュに保存 |
| TC-75 | `test_get_task_uses_cache` | GET /tasks/{id} がキャッシュヒット時に DB を呼ばない |
| TC-76 | `test_get_task_populates_cache_on_miss` | GET /tasks/{id} がキャッシュミス時に DB から取得しキャッシュに保存 |
| TC-77 | `test_create_task_invalidates_list_cache` | POST /tasks が tasks:list キャッシュを無効化 |
| TC-78 | `test_update_task_invalidates_caches` | PUT /tasks/{id} が tasks:list と tasks:{id} を無効化 |
| TC-79 | `test_delete_task_invalidates_caches` | DELETE /tasks/{id} が tasks:list と tasks:{id} を無効化 |

### 2.3 Graceful degradation テスト

| TC | テスト名 | 概要 |
|----|---------|------|
| TC-80 | `test_list_tasks_works_without_redis` | REDIS_URL 未設定でも GET /tasks が正常動作 |
| TC-81 | `test_create_task_works_without_redis` | REDIS_URL 未設定でも POST /tasks が正常動作 |

## 3. テスト実行

```bash
# 全テスト実行
DATABASE_URL=sqlite:// pytest tests/ -v

# キャッシュテストのみ
DATABASE_URL=sqlite:// pytest tests/test_cache.py -v
```

## 4. 想定テスト件数

| ファイル | v9 | v10 | 増減 |
|---------|-----|-----|------|
| test_main.py | 6 | 6 | - |
| test_tasks.py | 17 | 17 | - |
| test_attachments.py | 23 | 23 | - |
| test_observability.py | 8 | 8 | - |
| test_auth.py | 8 | 8 | - |
| **test_cache.py** | - | **19** | **+19** |
| **合計** | **62** | **81** | **+19** |
