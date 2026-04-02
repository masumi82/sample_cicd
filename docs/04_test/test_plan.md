# テスト計画書

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-02 |
| バージョン | 1.0 |

## 1. テスト方針

### 1.1 テスト種別

| 種別 | 対象 | ツール |
|------|------|--------|
| ユニットテスト | FastAPI エンドポイント | pytest + FastAPI TestClient |
| Lint チェック | app/, tests/ | ruff |
| ビルド検証 | Docker イメージ | docker build |

### 1.2 テスト範囲

本フェーズでは **アプリケーションのユニットテスト** に集中する。
インフラ（Terraform）やデプロイの結合テストは Phase 5 で実施する。

### 1.3 テストフレームワーク

| パッケージ | バージョン | 用途 |
|------------|-----------|------|
| pytest | latest | テストランナー |
| httpx | latest | FastAPI TestClient の依存 |
| ruff | latest | Lint チェック |

## 2. テスト対象

| 対象 | ファイル | 対応要件 |
|------|---------|----------|
| GET / エンドポイント | app/main.py | FR-1 |
| GET /health エンドポイント | app/main.py | FR-2 |

## 3. テストケース一覧

| ID | エンドポイント | テスト内容 | 期待結果 | 対応要件 |
|----|--------------|-----------|---------|----------|
| TC-01 | GET / | 正常リクエスト — ステータスコードとレスポンスボディ | 200 OK, `{"message": "Hello, World!"}` | FR-1 |
| TC-02 | GET / | Content-Type ヘッダー確認 | `application/json` | FR-1 |
| TC-03 | GET /health | 正常リクエスト — ステータスコードとレスポンスボディ | 200 OK, `{"status": "healthy"}` | FR-2 |
| TC-04 | GET /health | Content-Type ヘッダー確認 | `application/json` | FR-2 |
| TC-05 | GET /notfound | 存在しないパスへのリクエスト | 404 Not Found | — |
| TC-06 | POST / | 許可されていない HTTP メソッド | 405 Method Not Allowed | — |

## 4. テストファイル構成

```
tests/
├── __init__.py        # パッケージ初期化（空ファイル）
└── test_main.py       # FastAPI エンドポイントのテスト
```

## 5. テスト実行方法

### 5.1 ローカル実行

```bash
# 依存パッケージのインストール
pip install fastapi uvicorn[standard] httpx pytest ruff

# テスト実行
pytest tests/ -v

# Lint チェック
ruff check app/ tests/
```

### 5.2 CI 実行（GitHub Actions）

CI ジョブ内で以下のステップが自動実行される（`.github/workflows/ci-cd.yml`）:

1. `pip install -r app/requirements.txt` — アプリ依存
2. `pip install ruff pytest httpx` — テスト依存
3. `ruff check app/ tests/` — Lint
4. `pytest tests/ -v` — テスト実行

## 6. 合格基準

| 基準 | 条件 |
|------|------|
| テスト合格 | 全テストケース（TC-01 〜 TC-06）が PASS |
| Lint 合格 | `ruff check` がエラー 0 件 |
| カバレッジ | 本プロジェクトではカバレッジ閾値は設けない（学習用） |
