# CI/CD パイプライン設計書 (v4)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-06 |
| バージョン | 4.0 |
| 前バージョン | [cicd_v3.md](cicd_v3.md) (v3.0) |

## 変更概要

v4 ではアプリケーションコード（FastAPI）と Lambda 関数コードの両方が変更対象となる。
以下の変更を CI/CD パイプラインに加える:

- **CI**: Lambda コードの lint チェック追加、テスト依存パッケージ（moto）追加
- **CD**: Lambda 関数 3 つのデプロイステップ追加（zip + `aws lambda update-function-code`）

## 1. パイプライン全体像（v4）

```
┌─────────────────────────────────────────────────────────────────────┐
│                       GitHub Actions Workflow                        │
│                                                                     │
│  Trigger: push to main / Pull Request（変更なし）                    │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                          CI Job                               │  │
│  │                                                               │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────────┐  │  │
│  │  │ Checkout │─▶│  Lint    │─▶│  Test    │─▶│ Docker Build│  │  │
│  │  │          │  │  (ruff)  │  │ (pytest) │  │             │  │  │
│  │  └──────────┘  └──────────┘  └──────────┘  └─────────────┘  │  │
│  │               ↑ app/ + tests/                                 │  │
│  │               + lambda/ (追加)                                │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                              │                                      │
│                              │ (main branch only)                   │
│                              ▼                                      │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                          CD Job                               │  │
│  │                                                               │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────────┐  │  │
│  │  │ AWS Auth │─▶│ECR Login │─▶│ECR Push  │─▶│  ECS Deploy │  │  │
│  │  │          │  │          │  │(Docker)  │  │             │  │  │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────┬──────┘  │  │
│  │                                                     │         │  │
│  │                                                     ▼         │  │
│  │                                           ┌─────────────────┐ │  │
│  │                                           │ Lambda Deploy   │ │  │
│  │                                           │ (3 functions)   │ │  │
│  │                                           └─────────────────┘ │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

## 2. 変更箇所一覧

| # | 変更箇所 | v3 | v4 | 理由 |
|---|---------|-----|-----|------|
| 1 | CI: Lint 対象 | `app/ tests/` | `app/ tests/ lambda/` | Lambda コードを lint 対象に追加 |
| 2 | CI: テスト依存 | `pytest httpx` | `pytest httpx moto boto3` | moto による AWS SDK モックテストのため |
| 3 | CD: Lambda デプロイ | なし | zip パッケージ化 + `update-function-code` × 3 | Lambda 関数のデプロイ |

## 3. CI ジョブ変更詳細

### 3.1 Lint（変更あり）

```yaml
# Before (v3):
- name: Lint
  run: ruff check app/ tests/

# After (v4):
- name: Lint
  run: ruff check app/ tests/ lambda/
```

### 3.2 依存パッケージインストール（変更あり）

```yaml
# Before (v3):
- name: Install dependencies
  run: |
    pip install -r app/requirements.txt
    pip install ruff pytest httpx

# After (v4):
- name: Install dependencies
  run: |
    pip install -r app/requirements.txt
    pip install ruff pytest httpx moto boto3
```

> **設計判断 - `moto` と `boto3` を `requirements.txt` に含めない理由:**
> `moto` はテスト専用ライブラリであり、本番コンテナに含める必要はない。
> `boto3` は ECS 実行環境では Lambda と異なり自動提供されないため `requirements.txt` に含めるが、
> CI での追加インストールも明示的に行うことで依存を確認できる。

### 3.3 テスト（変更なし）

```yaml
- name: Test
  env:
    DATABASE_URL: "sqlite://"
  run: pytest tests/ -v
```

> `SQS_QUEUE_URL` と `EVENTBRIDGE_BUS_NAME` は tests/ の conftest.py で moto によりモックするため、
> GitHub Actions での環境変数設定は不要。

## 4. CD ジョブ変更詳細

### 4.1 Lambda デプロイステップ（新規追加）

ECS デプロイの後に以下のステップを追加する:

```yaml
- name: Package and deploy Lambda functions
  run: |
    # task_created_handler
    zip -j lambda/task_created_handler.zip lambda/task_created_handler.py
    aws lambda update-function-code \
      --function-name sample-cicd-task-created-handler \
      --zip-file fileb://lambda/task_created_handler.zip \
      --region ap-northeast-1

    # task_completed_handler
    zip -j lambda/task_completed_handler.zip lambda/task_completed_handler.py
    aws lambda update-function-code \
      --function-name sample-cicd-task-completed-handler \
      --zip-file fileb://lambda/task_completed_handler.zip \
      --region ap-northeast-1

    # task_cleanup_handler（psycopg2 を含む依存パッケージが必要）
    pip install psycopg2-binary -t lambda/task_cleanup_package/
    cp lambda/task_cleanup_handler.py lambda/task_cleanup_package/
    cd lambda/task_cleanup_package && zip -r ../task_cleanup_handler.zip . && cd ../..
    aws lambda update-function-code \
      --function-name sample-cicd-task-cleanup-handler \
      --zip-file fileb://lambda/task_cleanup_handler.zip \
      --region ap-northeast-1
```

> **設計判断 - `task_cleanup_handler` のパッケージング:**
> `task_cleanup_handler` は RDS 接続のために `psycopg2-binary` を使用する。
> Lambda は実行環境に `psycopg2` を持たないため、zip に同梱する必要がある。
> `task_created_handler` と `task_completed_handler` は標準ライブラリのみのため単純 zip で対応。

> **設計判断 - Lambda Layers を使わない理由:**
> v4 の学習スコープを超えるため、依存ライブラリの zip 同梱で対応する。
> 本番では psycopg2 などの共通依存を Lambda Layer にまとめることが推奨される。

### 4.2 必要な IAM 権限（GitHub Actions 用）

```
既存:
  ecr:GetAuthorizationToken, ecr:BatchCheckLayerAvailability, ecr:PutImage...
  ecs:RegisterTaskDefinition, ecs:DescribeServices, ecs:UpdateService...

v4 追加:
  lambda:UpdateFunctionCode（3 関数の ARN のみに制限）
```

> GitHub Actions に使用している IAM ユーザーまたはロールに、
> `lambda:UpdateFunctionCode` 権限を追加する必要がある。

## 5. 変更なし項目

| 項目 | 説明 |
|------|------|
| トリガー条件 | push to main / PR to main |
| CI/CD ジョブ分離 | CI 成功 + main ブランチの場合のみ CD 実行 |
| デプロイ方式（ECS） | ローリングデプロイ（`wait-for-service-stability: true`） |
| イメージタグ戦略 | Git SHA (7文字) + latest |
| Actions バージョン管理 | SHA でピン留め |
| GitHub Secrets | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`（変更なし） |
| Docker ビルドコンテキスト | `-f app/Dockerfile .`（プロジェクトルート） |
| テスト用 DB | SQLite インメモリ（`DATABASE_URL: "sqlite://"`） |

## 6. Lambda デプロイと ECS デプロイの関係

| 項目 | ECS (FastAPI) | Lambda |
|------|--------------|--------|
| デプロイ方式 | Docker イメージ → ECR → ECS rolling | zip → `update-function-code` |
| ロールバック | 旧 ECR タグで ECS タスク定義を更新 | 旧 zip を再アップロード |
| 設定変更 | Terraform（タスク定義の環境変数） | Terraform（Lambda 環境変数） |
| 依存関係 | ECS と Lambda は独立してデプロイ可能 | ECS の SQS 送信先が Lambda を前提とする |

> **設計判断 - ECS デプロイと Lambda デプロイの順序:**
> Lambda のデプロイは ECS デプロイの後に実施する（CD ジョブ内で順次実行）。
> ECS が先に新しいコードで起動し、SQS/EventBridge へメッセージを送信し始めるが、
> Lambda が古いコードであっても処理自体は継続するため、デプロイ順序は機能上問題ない。
