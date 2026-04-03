# テスト計画書 (v3)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-03 |
| バージョン | 3.0 |
| 前バージョン | [test_plan_v2.md](test_plan_v2.md) (v2.0) |

## 変更概要

v2 までのテスト（TC-01〜TC-18）はそのまま維持する。
v3 の変更はすべて Terraform に閉じており、アプリケーションコードに変更がないため、
新規ユニットテストは追加しない。

代わりに、**インフラの動作確認手順**（Auto Scaling の動作、RDS Multi-AZ の確認）を
本テスト計画書に記載する。

## 1. テスト方針

### 1.1 テスト種別

| 種別 | 対象 | ツール | v3 変更 |
|------|------|--------|---------|
| ユニットテスト | FastAPI エンドポイント | pytest + FastAPI TestClient | 変更なし |
| Lint チェック | app/, tests/ | ruff | 変更なし |
| ビルド検証 | Docker イメージ | docker build | 変更なし |
| インフラ動作確認 | Auto Scaling, RDS Multi-AZ | AWS コンソール / CLI | **新規（手動）** |

### 1.2 テスト範囲

v1・v2 のエンドポイントテストは引き続き全件実行する。
v3 のインフラ変更（Auto Scaling、RDS Multi-AZ）は手動での動作確認を行う。

### 1.3 テスト用データベース（変更なし）

| 環境 | DB | 理由 |
|------|------|------|
| テスト | SQLite インメモリ (`sqlite://`) | 外部依存なし、高速、CI 対応 |
| 本番 | PostgreSQL (RDS Multi-AZ) | データ永続化 + 高可用性 |

### 1.4 テスト実行コマンド

```bash
# 環境変数設定が必要（DATABASE_URL を設定しないと DB_* 環境変数を要求する）
DATABASE_URL=sqlite:// pytest tests/ -v

# Lint チェック
ruff check app/ tests/
```

> **注意:** `database.py` はモジュールロード時に DB エンジンを初期化するため、
> `DATABASE_URL=sqlite://` を明示的に指定して実行すること。

## 2. テスト対象

### 既存（v1・v2 から継続）

| 対象 | ファイル | 対応要件 | v3 変更 |
|------|---------|----------|---------|
| GET / | app/main.py | FR-1 | なし |
| GET /health | app/main.py | FR-2 | なし |
| GET /tasks | app/routers/tasks.py | FR-5 | なし |
| POST /tasks | app/routers/tasks.py | FR-6 | なし |
| GET /tasks/{id} | app/routers/tasks.py | FR-7 | なし |
| PUT /tasks/{id} | app/routers/tasks.py | FR-8 | なし |
| DELETE /tasks/{id} | app/routers/tasks.py | FR-9 | なし |

### 新規（v3 インフラ動作確認）

| 対象 | 確認方法 | 対応要件 |
|------|---------|----------|
| ECS Auto Scaling（スケールアウト） | 負荷ツール（ab）で CPU を 70% 超 | FR-11 |
| ECS Auto Scaling（スケールイン） | 負荷停止後にタスク数が 1 に戻ることを確認 | FR-11 |
| RDS Multi-AZ | AWS コンソールで Multi-AZ 有効を確認 | FR-12 |
| HTTPS コード（未デプロイ確認） | `terraform plan` で https.tf のリソースが count=0 であることを確認 | FR-13 |

## 3. テストケース一覧

### 既存（TC-01〜TC-18）— 変更なし

（[test_plan_v2.md](test_plan_v2.md) のセクション 3 を参照。全件 PASS 確認済み）

| ID | 結果（v3 実行） |
|----|--------------|
| TC-01〜TC-06 (v1) | 18/18 PASS |
| TC-07〜TC-18 (v2) | 18/18 PASS |

### 新規（v3 インフラ動作確認）

#### TC-19: Auto Scaling スケールアウト確認

| 項目 | 内容 |
|------|------|
| ID | TC-19 |
| 対象 | ECS Auto Scaling |
| 対応要件 | FR-11 |
| 前提条件 | `terraform apply` 済み、ECS サービスが稼働中 |
| 手順 | 1. `ab -n 10000 -c 100 http://<ALB_DNS>/` で負荷をかける |
| | 2. CloudWatch メトリクス「ECSServiceAverageCPUUtilization」を監視 |
| | 3. CPU が 70% を超えたら ECS コンソールでタスク数を確認 |
| 期待結果 | タスク数が 1 → 2（または 3）に増加する |
| 確認方法 | AWS コンソール > ECS > サービス > タスク数 |

#### TC-20: Auto Scaling スケールイン確認

| 項目 | 内容 |
|------|------|
| ID | TC-20 |
| 対象 | ECS Auto Scaling |
| 対応要件 | FR-11 |
| 前提条件 | TC-19 完了後、タスク数が 2 以上の状態 |
| 手順 | 1. 負荷ツールを停止する |
| | 2. 300 秒（スケールイン クールダウン）以上待機する |
| | 3. ECS コンソールでタスク数を確認 |
| 期待結果 | タスク数が 1 に戻る |
| 確認方法 | AWS コンソール > ECS > サービス > タスク数 |

> **注意:** スケールインは段階的（300 秒ごとに 1 タスク削減）のため、
> 複数タスクから 1 タスクに戻るまでに時間がかかる場合がある。

#### TC-21: RDS Multi-AZ 確認

| 項目 | 内容 |
|------|------|
| ID | TC-21 |
| 対象 | RDS Multi-AZ 設定 |
| 対応要件 | FR-12 |
| 手順 | 1. AWS コンソール > RDS > データベース > `sample-cicd` を開く |
| | 2. 「設定」タブで「マルチ AZ」を確認 |
| 期待結果 | マルチ AZ: はい（または「マルチ AZ」列に「はい」） |
| CLI 確認 | `aws rds describe-db-instances --db-instance-identifier sample-cicd --query 'DBInstances[0].MultiAZ'` |
| 期待 CLI 出力 | `true` |

#### TC-22: HTTPS コード（count=0）確認

| 項目 | 内容 |
|------|------|
| ID | TC-22 |
| 対象 | https.tf（コードのみ、未デプロイ） |
| 対応要件 | FR-13 |
| 手順 | `cd infra && terraform plan 2>&1 \| grep "https\|acm\|route53"` を実行 |
| 期待結果 | ACM・Route53・HTTPS リスナーのリソースに `(count = 0)` または「変更なし」が表示される |
| 確認内容 | `enable_https = false`（デフォルト）のため、HTTPS リソースが作成されないことを確認 |

## 4. テストファイル構成（変更なし）

```
tests/
├── __init__.py        # パッケージ初期化（空ファイル）
├── conftest.py        # テスト用 DB 設定（SQLite インメモリ、get_db オーバーライド）
├── test_main.py       # v1 エンドポイントテスト (TC-01〜TC-06)
└── test_tasks.py      # v2 タスク CRUD テスト (TC-07〜TC-18)
```

## 5. テスト実行方法

### 5.1 ローカル実行

```bash
# 依存パッケージのインストール
pip install -r app/requirements.txt
pip install ruff pytest httpx

# 全テスト実行（DATABASE_URL が必須）
DATABASE_URL=sqlite:// pytest tests/ -v

# Lint チェック
ruff check app/ tests/
```

### 5.2 CI 実行（GitHub Actions）

v2 と同じワークフロー（変更なし）。
`.github/workflows/ci-cd.yml` では `DATABASE_URL: "sqlite://"` を環境変数として設定済み。

### 5.3 インフラ動作確認（手動、deploy 後）

`docs/05_deploy/deploy_procedure_v3.md` のデプロイ手順完了後に TC-19〜TC-22 を実施する。

## 6. 合格基準

| 基準 | 条件 |
|------|------|
| ユニットテスト合格 | TC-01〜TC-18 が全件 PASS（`18 passed`） |
| Lint 合格 | `ruff check` がエラー 0 件（`All checks passed!`） |
| Auto Scaling 確認 | TC-19（スケールアウト）、TC-20（スケールイン）が期待通りの動作 |
| RDS Multi-AZ 確認 | TC-21 の CLI 出力が `true` |
| HTTPS コード確認 | TC-22 で HTTPS リソースが count=0 であることを確認 |
