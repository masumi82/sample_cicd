# Terraform リソース設計書 (v2)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-03 |
| バージョン | 2.0 |
| 前バージョン | [infrastructure.md](infrastructure.md) (v1.0) |

## 変更概要

v1 の 20 リソースに 10 リソースを追加し、合計 30 リソースとする。
既存リソースのうち 3 つ（ecs.tf, iam.tf, security_groups.tf）に変更を加える。

## 1. Terraform リソース一覧

### v1 から継続（20 リソース）

| # | リソースタイプ | リソース名 | 用途 | v2 変更 |
|---|---------------|-----------|------|---------|
| 1 | `aws_vpc` | `main` | VPC | なし |
| 2 | `aws_subnet` | `public_1` | パブリックサブネット (AZ-a) | なし |
| 3 | `aws_subnet` | `public_2` | パブリックサブネット (AZ-c) | なし |
| 4 | `aws_internet_gateway` | `main` | IGW | なし |
| 5 | `aws_route_table` | `public` | パブリックルートテーブル | なし |
| 6 | `aws_route_table_association` | `public_1` | サブネット 1 関連付け | なし |
| 7 | `aws_route_table_association` | `public_2` | サブネット 2 関連付け | なし |
| 8 | `aws_security_group` | `alb` | ALB 用 SG | なし |
| 9 | `aws_security_group` | `ecs_tasks` | ECS タスク用 SG | なし |
| 10 | `aws_lb` | `main` | ALB | なし |
| 11 | `aws_lb_target_group` | `app` | ターゲットグループ | なし |
| 12 | `aws_lb_listener` | `http` | HTTP リスナー | なし |
| 13 | `aws_ecr_repository` | `app` | ECR リポジトリ | なし |
| 14 | `aws_ecs_cluster` | `main` | ECS クラスター | なし |
| 15 | `aws_ecs_task_definition` | `app` | ECS タスク定義 | **変更** |
| 16 | `aws_ecs_service` | `app` | ECS サービス | なし |
| 17 | `aws_iam_role` | `ecs_task_execution` | タスク実行ロール | なし |
| 18 | `aws_iam_role` | `ecs_task` | タスクロール | なし |
| 19 | `aws_iam_role_policy_attachment` | `ecs_task_execution` | ポリシーアタッチ | なし |
| 20 | `aws_cloudwatch_log_group` | `app` | ロググループ | なし |

### v2 新規（10 リソース）

| # | リソースタイプ | リソース名 | 用途 | ファイル |
|---|---------------|-----------|------|----------|
| 21 | `aws_subnet` | `private_1` | プライベートサブネット (AZ-a) | main.tf |
| 22 | `aws_subnet` | `private_2` | プライベートサブネット (AZ-c) | main.tf |
| 23 | `aws_route_table` | `private` | プライベートルートテーブル | main.tf |
| 24 | `aws_route_table_association` | `private_1` | プライベートサブネット 1 関連付け | main.tf |
| 25 | `aws_route_table_association` | `private_2` | プライベートサブネット 2 関連付け | main.tf |
| 26 | `aws_security_group` | `rds` | RDS 用 SG | security_groups.tf |
| 27 | `aws_db_subnet_group` | `main` | RDS サブネットグループ | rds.tf |
| 28 | `aws_db_instance` | `main` | RDS PostgreSQL | rds.tf |
| 29 | `random_password` | `db_password` | DB パスワード自動生成 | secrets.tf |
| 30 | `aws_secretsmanager_secret` | `db_credentials` | Secrets Manager シークレット | secrets.tf |
| 31 | `aws_secretsmanager_secret_version` | `db_credentials` | シークレット値 | secrets.tf |
| 32 | `aws_iam_policy` | `secrets_manager_read` | Secrets Manager 読み取りポリシー | iam.tf |
| 33 | `aws_iam_role_policy_attachment` | `ecs_secrets_manager` | ポリシーアタッチ | iam.tf |

> **注意:** `random_password` は AWS リソースではないが、Terraform で管理するリソースとして計上。
> 実際の AWS リソース追加は 10 個（#21〜#31, #32〜#33 のうち AWS 側は 12 個）。

## 2. ファイル構成

```
infra/
├── main.tf              # Provider, VPC, サブネット, IGW, ルートテーブル [変更]
├── alb.tf               # ALB, ターゲットグループ, リスナー [変更なし]
├── ecr.tf               # ECR リポジトリ [変更なし]
├── ecs.tf               # ECS クラスター, タスク定義, サービス [変更]
├── iam.tf               # IAM ロール, ポリシー [変更]
├── security_groups.tf   # セキュリティグループ [変更]
├── logs.tf              # CloudWatch ロググループ [変更なし]
├── rds.tf               # RDS PostgreSQL, DB Subnet Group [新規]
├── secrets.tf           # Secrets Manager, random_password [新規]
├── variables.tf         # 入力変数 [変更]
├── outputs.tf           # 出力値 [変更]
└── terraform.tfvars     # 変数値 [変更]
```

## 3. 新規リソース詳細設計

### 3.1 プライベートサブネット（main.tf に追加）

```
Private Subnet 1:
  CIDR: 10.0.11.0/24
  AZ: ap-northeast-1a
  Map Public IP: false

Private Subnet 2:
  CIDR: 10.0.12.0/24
  AZ: ap-northeast-1c
  Map Public IP: false

Route Table (private):
  Route: (ローカルルートのみ、インターネットへのルートなし)
  Association: Private Subnet 1, Private Subnet 2
```

> **設計判断:** NAT Gateway は使用しない（コスト約 $45/月を削減）。
> プライベートサブネットからインターネットへの通信は不要（RDS のみ配置するため）。

### 3.2 RDS PostgreSQL（rds.tf 新規）

```
DB Subnet Group:
  Name: sample-cicd
  Subnets: Private Subnet 1, Private Subnet 2

RDS Instance:
  Identifier: sample-cicd
  Engine: postgres
  Engine Version: 15
  Instance Class: db.t3.micro
  Allocated Storage: 20 (GB)
  Storage Type: gp2
  DB Name: sample_cicd
  Username: postgres
  Password: random_password.db_password.result
  Port: 5432
  VPC Security Group: RDS SG
  DB Subnet Group: sample-cicd
  Multi-AZ: false
  Publicly Accessible: false
  Skip Final Snapshot: true
  Backup Retention Period: 0
  Delete Protection: false
```

> **設計判断（学習用最小構成）:**
> - `skip_final_snapshot = true`: 削除時にスナップショット不要
> - `backup_retention_period = 0`: 自動バックアップ無効
> - `deletion_protection = false`: `terraform destroy` で削除可能
> - `multi_az = false`: Single-AZ（コスト削減）

### 3.3 Secrets Manager（secrets.tf 新規）

```
Provider: random (追加)

random_password:
  Name: db_password
  Length: 16
  Special: true
  Override Special: "!#$%&*()-_=+[]{}|:,.<>?"

Secrets Manager Secret:
  Name: sample-cicd/db-credentials
  Description: "Database credentials for sample-cicd"

Secrets Manager Secret Version:
  Secret: sample-cicd/db-credentials
  Value (JSON):
    {
      "username": "postgres",
      "password": "<random_password>",
      "host": "<rds_endpoint>",
      "port": "5432",
      "dbname": "sample_cicd"
    }
```

> **設計判断:**
> - `random_password` でパスワードを自動生成（16 文字以上、特殊文字含む）
> - RDS エンドポイントは `aws_db_instance.main.address` で動的に取得
> - JSON 形式で保存し、ECS タスク定義の `secrets` ブロックで個別キーを参照

### 3.4 RDS 用セキュリティグループ（security_groups.tf に追加）

```
RDS Security Group:
  Name: sample-cicd-rds-sg
  Description: Security group for RDS
  VPC: main

  Ingress:
    - Port: 5432, Protocol: TCP, Source: ECS Tasks SG
  Egress:
    - All traffic to 0.0.0.0/0
```

## 4. 既存リソース変更詳細

### 4.1 ECS タスク定義（ecs.tf 変更）

**変更点:** コンテナ定義に `secrets` ブロックを追加し、Secrets Manager から DB 接続情報を注入。

```json
{
  "name": "app",
  "image": "<ECR_URI>:latest",
  "essential": true,
  "portMappings": [{"containerPort": 8000, "protocol": "tcp"}],
  "secrets": [
    {"name": "DB_USERNAME", "valueFrom": "<secret_arn>:username::"},
    {"name": "DB_PASSWORD", "valueFrom": "<secret_arn>:password::"},
    {"name": "DB_HOST",     "valueFrom": "<secret_arn>:host::"},
    {"name": "DB_PORT",     "valueFrom": "<secret_arn>:port::"},
    {"name": "DB_NAME",     "valueFrom": "<secret_arn>:dbname::"}
  ],
  "logConfiguration": { ... }
}
```

> **Secrets の valueFrom 形式:** `<secret_arn>:<json_key>::`
> 末尾の `::` はバージョンステージとバージョン ID の省略（最新版を使用）。

### 4.2 IAM（iam.tf 変更）

**追加:** ECS タスク実行ロールに Secrets Manager 読み取り権限を付与。

```
IAM Policy (secrets_manager_read):
  Name: sample-cicd-secrets-manager-read
  Action: secretsmanager:GetSecretValue
  Resource: <secrets_manager_secret_arn>

Policy Attachment:
  Role: ecs_task_execution
  Policy: secrets_manager_read
```

> **設計判断:** `secretsmanager:GetSecretValue` のみ、対象シークレットの ARN に限定。
> ワイルドカードは使用せず最小権限の原則に従う。

### 4.3 Provider（main.tf 変更）

**追加:** `random` プロバイダーを追加。

```
required_providers {
  aws = {
    source  = "hashicorp/aws"
    version = "~> 5.0"
  }
  random = {
    source  = "hashicorp/random"
    version = "~> 3.0"
  }
}
```

## 5. 変数設計（variables.tf 変更）

### v1 変数（変更なし）

| 変数名 | 型 | デフォルト値 | 説明 |
|--------|----|-------------|------|
| `project_name` | string | `"sample-cicd"` | プロジェクト名 |
| `aws_region` | string | `"ap-northeast-1"` | AWS リージョン |
| `vpc_cidr` | string | `"10.0.0.0/16"` | VPC CIDR |
| `app_port` | number | `8000` | アプリケーションポート |
| `fargate_cpu` | number | `256` | Fargate CPU |
| `fargate_memory` | number | `512` | Fargate メモリ |
| `desired_count` | number | `1` | ECS タスク数 |

### v2 追加変数

| 変数名 | 型 | デフォルト値 | 説明 |
|--------|----|-------------|------|
| `db_instance_class` | string | `"db.t3.micro"` | RDS インスタンスクラス |
| `db_allocated_storage` | number | `20` | RDS ストレージサイズ (GB) |
| `db_name` | string | `"sample_cicd"` | データベース名 |
| `db_port` | number | `5432` | データベースポート |

## 6. 出力値設計（outputs.tf 変更）

### v1 出力（変更なし）

| 出力名 | 説明 |
|--------|------|
| `alb_dns_name` | ALB の DNS 名 |
| `ecr_repository_url` | ECR リポジトリの URL |
| `ecs_cluster_name` | ECS クラスター名 |
| `ecs_service_name` | ECS サービス名 |

### v2 追加出力

| 出力名 | 説明 |
|--------|------|
| `rds_endpoint` | RDS エンドポイント |
| `secrets_manager_arn` | Secrets Manager シークレットの ARN |

## 7. リソース依存関係

```
random_password.db_password
    └──▶ aws_secretsmanager_secret_version.db_credentials
              └──▶ aws_ecs_task_definition.app (secrets block)

aws_subnet.private_1 + aws_subnet.private_2
    └──▶ aws_db_subnet_group.main
              └──▶ aws_db_instance.main
                        └──▶ aws_secretsmanager_secret_version.db_credentials (host)

aws_security_group.ecs_tasks
    └──▶ aws_security_group.rds (ingress source)

aws_secretsmanager_secret.db_credentials
    └──▶ aws_iam_policy.secrets_manager_read (resource ARN)
              └──▶ aws_iam_role_policy_attachment.ecs_secrets_manager
```

## 8. State 管理

v1 と同様。ローカルバックエンド。

| 項目 | 値 |
|------|------|
| Backend | local |
| State file | `infra/terraform.tfstate` |
