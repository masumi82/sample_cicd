# CLAUDE.md

## Project Overview

CI/CD学習を目的としたサーバーレスコンテナアプリケーションプロジェクト。
GitHub Actions + ECS(Fargate) による CI/CD パイプライン構築がメインテーマ。
アプリケーション自体は最小限の FastAPI Hello World API。

## Architecture

```
GitHub (push to main)
  └── GitHub Actions
        ├── Lint + Test (pytest)
        ├── Docker Build → ECR Push
        └── ECS (Fargate) Deploy
```

### AWS Services

| Service | Purpose |
|---------|---------|
| ECR | Docker image registry |
| ECS (Fargate) | Container runtime |
| ALB | Load balancer / HTTP endpoint |
| VPC | Network (public/private subnets) |
| IAM | Roles and policies |
| CloudWatch Logs | Container logs |

### Tech Stack

- **Language**: Python 3.12
- **Framework**: FastAPI
- **IaC**: Terraform
- **CI/CD**: GitHub Actions
- **Container**: Docker
- **Region**: ap-northeast-1 (Tokyo)

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

## Project Structure

```
sample_cicd/
├── CLAUDE.md
├── docs/
│   ├── 01_requirements/
│   ├── 02_design/
│   ├── 04_test/
│   └── 05_deploy/
├── app/                    # FastAPI application
│   ├── main.py
│   ├── requirements.txt
│   └── Dockerfile
├── infra/                  # Terraform
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── tests/                  # pytest
├── .github/
│   └── workflows/
│       └── ci-cd.yml       # GitHub Actions
└── .gitignore
```

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
