# CI/CD パイプライン設計書 (v2)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-03 |
| バージョン | 2.0 |
| 前バージョン | [cicd.md](cicd.md) (v1.0) |

## 変更概要

v1 パイプラインからの変更は最小限:
- Docker ビルドコンテキストを `./app` からプロジェクトルート（`.`）に変更
- Dockerfile パスを `-f app/Dockerfile` で明示指定

パイプラインの構造（CI → CD の 2 ジョブ構成）やトリガー条件は変更なし。

## 1. パイプライン全体像

```
┌─────────────────────────────────────────────────────────────────┐
│                     GitHub Actions Workflow                      │
│                                                                 │
│  Trigger: push to main / Pull Request (変更なし)                │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    CI Job                                │   │
│  │                                                         │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────┐ │   │
│  │  │ Checkout │─▶│  Lint    │─▶│  Test    │─▶│ Build  │ │   │
│  │  │          │  │  (ruff)  │  │ (pytest) │  │(Docker)│ │   │
│  │  └──────────┘  └──────────┘  └──────────┘  └────────┘ │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                  │
│                              │ (main branch only)               │
│                              ▼                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    CD Job                                │   │
│  │                                                         │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────┐ │   │
│  │  │ AWS Auth │─▶│ECR Login │─▶│ECR Push  │─▶│  ECS   │ │   │
│  │  │          │  │          │  │          │  │ Deploy │ │   │
│  │  └──────────┘  └──────────┘  └──────────┘  └────────┘ │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## 2. 変更箇所一覧

| # | 変更箇所 | v1 | v2 | 理由 |
|---|---------|-----|-----|------|
| 1 | CI: Docker build コンテキスト | `./app` | `-f app/Dockerfile .` | app/ をパッケージ化するため |
| 2 | CD: Docker build コンテキスト | `./app` | `-f app/Dockerfile .` | 同上 |

## 3. 変更詳細

### 3.1 Docker ビルドコンテキストの変更理由

v2 で `app/` ディレクトリを Python パッケージ化（`__init__.py` 追加）するにあたり、
Dockerfile 内で `app/` ディレクトリ構造を維持したままコピーする必要がある。

**v1（コンテキスト = `./app`）:**

```dockerfile
# Dockerfile is inside ./app, context is ./app
COPY requirements.txt .
COPY main.py .
```

**v2（コンテキスト = プロジェクトルート）:**

```dockerfile
# Dockerfile is inside ./app, context is project root
COPY app/requirements.txt .
COPY app/ ./app/
```

### 3.2 CI ジョブの変更

**v1:**

```yaml
- name: Build Docker image
  run: docker build -t sample-cicd:test ./app
```

**v2:**

```yaml
- name: Build Docker image
  run: docker build -t sample-cicd:test -f app/Dockerfile .
```

### 3.3 CD ジョブの変更

**v1:**

```yaml
- name: Build, tag, and push image to ECR
  run: |
    SHORT_SHA=$(echo $IMAGE_TAG | cut -c1-7)
    docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$SHORT_SHA ./app
    ...
```

**v2:**

```yaml
- name: Build, tag, and push image to ECR
  run: |
    SHORT_SHA=$(echo $IMAGE_TAG | cut -c1-7)
    docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$SHORT_SHA -f app/Dockerfile .
    ...
```

## 4. 変更なし項目

以下は v1 から変更なし:

| 項目 | 説明 |
|------|------|
| トリガー条件 | push to main / PR to main |
| CI ジョブ構成 | Checkout → Setup Python → Install deps → Lint → Test → Build |
| CD ジョブ構成 | Checkout → AWS Auth → ECR Login → Build & Push → Render Task Def → Deploy |
| CD 実行条件 | CI 成功 + main ブランチ |
| デプロイ方式 | ローリングデプロイ（wait-for-service-stability: true） |
| イメージタグ戦略 | Git SHA (7文字) + latest |
| Actions バージョン管理 | SHA でピン留め |
| GitHub Secrets | AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY |

## 5. テスト実行の注意点

v2 のテストでは SQLite インメモリ DB を使用するため、CI 環境への追加依存は不要。

```yaml
- name: Install dependencies
  run: |
    pip install -r app/requirements.txt
    pip install ruff pytest httpx

- name: Test
  run: pytest tests/ -v
```

`requirements.txt` に `sqlalchemy` と `psycopg2-binary` が追加されるが、
テスト時は SQLite を使用するため `psycopg2-binary` は import されない。

> **注意:** `psycopg2-binary` は CI の `pip install` でインストールされるが、
> テスト実行時には使用されない。PostgreSQL サーバーへの接続はテストでは発生しない。
