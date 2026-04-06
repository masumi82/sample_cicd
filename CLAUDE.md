# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CI/CD学習を目的としたサーバーレスコンテナアプリケーションプロジェクト。
GitHub Actions + ECS(Fargate) による CI/CD パイプライン構築がメインテーマ。

### v1 (完了): Hello World API
最小限の FastAPI Hello World API (`GET /`, `GET /health`)。

### v2 (完了): タスク管理 API + RDS PostgreSQL
v1 に RDS PostgreSQL を追加し、タスク管理 CRUD API を実装する。
新規学習テーマ: RDS, プライベートサブネット, Secrets Manager, SQLAlchemy, Alembic。
ドキュメントは `_v2` サフィックスで v1 と並行管理する。

### v3 (進行中): ECS Auto Scaling + HTTPS準備
ECS Service Auto Scaling を実装し、負荷に応じたタスク数の自動調整を学習する。
新規学習テーマ: Application Auto Scaling, Target Tracking Policy, CloudWatch Alarms。
HTTPS 化 (ACM + Route53) は Terraform コードのみ作成（デプロイなし）。
ドキュメントは `_v3` サフィックスで管理する。

### v4 (進行中): イベント駆動アーキテクチャ
SQS + Lambda + EventBridge を使った非同期処理パターンを学習する。
新規学習テーマ: SQS, Lambda, EventBridge, イベント駆動設計。
既存タスク管理APIにイベント発行を追加し、Lambda で非同期処理する。

### v5 (予定): ストレージ + マルチ環境
S3 + CloudFront + Terraform Workspace を使ったストレージとマルチ環境管理を学習する。
新規学習テーマ: S3, CloudFront, Presigned URL, Terraform Workspace。

## Common Commands

### Lint & Test (CI と同じ手順)
```bash
pip install -r app/requirements.txt && pip install ruff pytest httpx
ruff check app/ tests/          # lint
DATABASE_URL=sqlite:// pytest tests/ -v                # run all tests
DATABASE_URL=sqlite:// pytest tests/test_tasks.py::test_create_task -v  # run single test
```

> `DATABASE_URL` は必須。未設定だと `database.py` モジュールロード時に `DB_*` 環境変数を要求してエラーになる。CI では `env: DATABASE_URL: "sqlite://"` で設定済み。

### Local Dev Server
```bash
cd app && python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### Docker
```bash
docker build -t sample-cicd:test ./app
docker run -p 8000:8000 sample-cicd:test
```

### Terraform (from `infra/` directory)
```bash
cd infra
terraform init
terraform plan
terraform apply
```

## Architecture

```
GitHub (push to main)
  └── GitHub Actions (.github/workflows/ci-cd.yml)
        ├── CI: ruff check → pytest → docker build (on all pushes/PRs to main)
        └── CD: ECR push → ECS deploy (main branch only)
```

- **app/**: FastAPI app。`main.py` + `routers/tasks.py` (Task CRUD) + `models.py` + `schemas.py` + `database.py`。起動時に Alembic マイグレーションを自動実行 (`lifespan` ハンドラ)。DB接続は `DATABASE_URL` 環境変数があればそれを使用し、なければ `DB_*` 変数から構築。
- **tests/**: `conftest.py` が SQLite in-memory DB で `get_db` 依存を上書き。各テストで `Base.metadata.create_all/drop_all` を実行（`autouse=True` fixture）。
- **infra/**: Terraform split by resource type。`autoscaling.tf` (v3: ECS CPU Target Tracking)、`https.tf` (v3: `enable_https = false` でデフォルト無効)、`outputs.tf` が v3 で追加。`terraform.tfvars` に設定値。
- **CI/CD**: GitHub Actions pipeline with `ci` (lint/test/build) and `cd` (ECR push + ECS rolling deploy) jobs. Actions pinned by SHA. CD uses short SHA as image tag + `latest`.

### AWS (ap-northeast-1)

**v1**: ECR → ECS Fargate (public subnets, 256 CPU / 512 MB) → ALB (HTTP listener) with CloudWatch Logs.

**v2 (追加)**: ALB → ECS Fargate → RDS PostgreSQL (private subnets) + Secrets Manager for DB credentials. Terraform adds `rds.tf`, `secrets.tf`, private subnets in `main.tf`.

**v3 (追加)**: ECS Auto Scaling (CPU 70% target tracking, min=1/max=3, scale-out cooldown 60s)。HTTPS は `enable_https = false` でコードのみ存在、デプロイ未実施。

> **注意**: `infra/terraform.tfstate` がリポジトリにコミットされている。本番運用では remote state (S3 backend) への移行を推奨。

## Development Process

ウォーターフォール型で以下のフェーズ順に進行する。
各フェーズの成果物は `docs/` 配下にドキュメントとして残す。

| Phase | Output | Directory |
|-------|--------|-----------|
| 1. Requirements | 要件定義書 | `docs/01_requirements/` |
| 2. Design | 設計書 (アーキテクチャ, API, DB, CI/CD) | `docs/02_design/` |
| 3. Implementation | アプリコード, Terraform, Dockerfile, GitHub Actions | `app/`, `infra/`, `.github/` |
| 4. Test | テスト計画書, テストコード | `docs/04_test/`, `tests/` |
| 5. Deploy | デプロイ手順書, 動作確認記録 | `docs/05_deploy/` |

**Important**: 現在のフェーズが完了するまで次のフェーズに進まないこと。
フェーズ完了時は `/phase-gate` スキルを使って完了チェックを行う。

## User Context

- AWS アカウントあり、CLI 未設定（セットアップから対応が必要）
- GitLab Runner の経験あり、GitHub Actions は初めて
- Docker は docker run レベル（Dockerfile 作成は学習対象）
- Terraform 初学者

## Language

All communication with the user must be in **Japanese**.
Source code, code comments, and technical identifiers remain in English.

## Coding Conventions

- Python: follow PEP 8, type hints required, Google-style docstrings
- Terraform: use snake_case for resource names, tag all resources with `Project = "sample-cicd"`
- Docker: multi-stage build, non-root user
- GitHub Actions: pin action versions with SHA

## Security

- Never hardcode AWS credentials, secrets, or API keys
- Use IAM roles (not access keys) for ECS tasks
- Store secrets in GitHub Actions secrets
- Ensure `.env` and credential files are in `.gitignore`
- ECR images should be scanned for vulnerabilities
- DB credentials must be managed via AWS Secrets Manager (v2)
- RDS must be placed in private subnets, accessible only from ECS security group (v2)
