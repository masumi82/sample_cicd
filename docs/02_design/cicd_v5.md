# CI/CD パイプライン設計書 (v5)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-06 |
| バージョン | 5.0 |
| 前バージョン | [cicd_v4.md](cicd_v4.md) (v4.0) |

## 変更概要

v5 では Terraform Workspace によるマルチ環境管理を導入する。
CI/CD パイプラインを Workspace 対応に変更し、デプロイ先の環境名をリソース名に含める。

- **CI**: 変更なし（lint / test / docker build は環境非依存）
- **CD**: ECS / Lambda のデプロイ先リソース名に環境名（`dev`）を含める

## 1. パイプライン全体像（v5）

```
┌─────────────────────────────────────────────────────────────────────┐
│                       GitHub Actions Workflow                        │
│                                                                     │
│  Trigger: push to main / Pull Request（変更なし）                    │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                          CI Job（変更なし）                    │  │
│  │                                                               │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────────┐  │  │
│  │  │ Checkout │─▶│  Lint    │─▶│  Test    │─▶│ Docker Build│  │  │
│  │  │          │  │  (ruff)  │  │ (pytest) │  │             │  │  │
│  │  └──────────┘  └──────────┘  └──────────┘  └─────────────┘  │  │
│  │               app/ + tests/ + lambda/                         │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                              │                                      │
│                              │ (main branch only)                   │
│                              ▼                                      │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                    CD Job（Workspace 対応）                    │  │
│  │                                                               │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────────┐  │  │
│  │  │ AWS Auth │─▶│ECR Login │─▶│ECR Push  │─▶│  ECS Deploy │  │  │
│  │  │          │  │          │  │(Docker)  │  │  (dev env)  │  │  │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────┬──────┘  │  │
│  │                                                     │         │  │
│  │                                                     ▼         │  │
│  │                                           ┌─────────────────┐ │  │
│  │                                           │ Lambda Deploy   │ │  │
│  │                                           │ (3 functions)   │ │  │
│  │                                           │ (dev env)       │ │  │
│  │                                           └─────────────────┘ │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

## 2. 変更箇所一覧

| # | 変更箇所 | v4 | v5 | 理由 |
|---|---------|-----|-----|------|
| 1 | CD: 環境変数 | リソース名固定（`sample-cicd-*`） | 環境名付き（`sample-cicd-dev-*`） | Workspace 対応 |
| 2 | CD: ECR リポジトリ名 | `sample-cicd` | `sample-cicd-dev` | 環境別 ECR |
| 3 | CD: ECS クラスタ名 | `sample-cicd` | `sample-cicd-dev` | 環境別 ECS |
| 4 | CD: ECS サービス名 | `sample-cicd` | `sample-cicd-dev` | 環境別 ECS |
| 5 | CD: Lambda 関数名 | `sample-cicd-task-*-handler` | `sample-cicd-dev-task-*-handler` | 環境別 Lambda |
| 6 | CD: 環境パラメータ | ハードコード | `DEPLOY_ENV` 変数で制御 | 拡張性 |

## 3. CI ジョブ（変更なし）

CI ジョブはアプリケーションコードの品質チェック（lint / test / build）を行うため、
デプロイ先の環境には依存しない。v4 から変更なし。

```yaml
ci:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@...
    - uses: actions/setup-python@...
      with:
        python-version: "3.12"
    - name: Install dependencies
      run: |
        pip install -r app/requirements.txt
        pip install ruff pytest httpx "moto[sqs,events]"
    - name: Lint
      run: ruff check app/ tests/ lambda/
    - name: Test
      env:
        DATABASE_URL: "sqlite://"
      run: pytest tests/ -v
    - name: Build Docker image
      run: docker build -t sample-cicd:test -f app/Dockerfile .
```

## 4. CD ジョブ変更詳細

### 4.1 環境変数の導入

```yaml
cd:
  needs: ci
  if: github.ref == 'refs/heads/main'
  runs-on: ubuntu-latest
  env:
    DEPLOY_ENV: dev    # デプロイ先環境（将来 prod 対応時に変更）
    AWS_REGION: ap-northeast-1
```

> **設計判断 - `DEPLOY_ENV` 変数:**
> 現在は `dev` 固定だが、将来的に `prod` 環境へのデプロイを追加する際に、
> この変数を変更するだけで対応できるようにする。
> 本格的な運用では GitHub Actions の `environment` 機能や手動トリガーを使う。

### 4.2 ECR Push（変更あり）

```yaml
# Before (v4):
- name: Build and push Docker image
  env:
    ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
    ECR_REPOSITORY: sample-cicd
    IMAGE_TAG: ${{ github.sha }}

# After (v5):
- name: Build and push Docker image
  env:
    ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
    ECR_REPOSITORY: sample-cicd-${{ env.DEPLOY_ENV }}
    IMAGE_TAG: ${{ github.sha }}
```

### 4.3 ECS Deploy（変更あり）

```yaml
# Before (v4):
- name: Deploy to ECS
  uses: aws-actions/amazon-ecs-deploy-task-definition@...
  with:
    cluster: sample-cicd
    service: sample-cicd

# After (v5):
- name: Deploy to ECS
  uses: aws-actions/amazon-ecs-deploy-task-definition@...
  with:
    cluster: sample-cicd-${{ env.DEPLOY_ENV }}
    service: sample-cicd-${{ env.DEPLOY_ENV }}
```

### 4.4 Lambda Deploy（変更あり）

```yaml
# Before (v4):
- name: Package and deploy Lambda functions
  run: |
    for func in task_created_handler task_completed_handler task_cleanup_handler; do
      ...
      aws lambda update-function-code \
        --function-name sample-cicd-${func//_/-} \
        ...

# After (v5):
- name: Package and deploy Lambda functions
  run: |
    for func in task_created_handler task_completed_handler task_cleanup_handler; do
      ...
      aws lambda update-function-code \
        --function-name sample-cicd-${{ env.DEPLOY_ENV }}-${func//_/-} \
        ...
```

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
| Lint 対象 | `app/ tests/ lambda/`（変更なし） |
| テスト依存 | `moto[sqs,events]`（v4 から変更なし） |

## 6. 将来の拡張（本 v5 ではスコープ外）

### prod 環境へのデプロイ

将来的に `prod` 環境へのデプロイを追加する場合:

```yaml
# 方法 1: GitHub Actions environments
cd-prod:
  needs: ci
  if: github.ref == 'refs/heads/main'
  environment: production    # 手動承認を要求
  env:
    DEPLOY_ENV: prod

# 方法 2: workflow_dispatch による手動トリガー
on:
  workflow_dispatch:
    inputs:
      environment:
        type: choice
        options: [dev, prod]
```

> v5 の学習スコープでは `dev` のみデプロイし、`prod` はパターンの提示のみとする。

## 7. IAM 権限（変更なし）

v4 で追加した以下の権限は v5 でも引き続き必要:

```
ECR: GetAuthorizationToken, BatchCheckLayerAvailability, PutImage, ...
ECS: RegisterTaskDefinition, DescribeServices, UpdateService, ...
Lambda: UpdateFunctionCode（3 関数の ARN のみ）
```

> リソース名に環境名が含まれるようになるため、IAM ポリシーの Resource ARN も
> `sample-cicd-dev-*` パターンに合わせて更新する必要がある。
