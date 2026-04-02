# Terraform リソース設計書

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-02 |
| バージョン | 1.0 |

## 1. Terraform リソース一覧

| # | リソースタイプ | リソース名 | 用途 |
|---|---------------|-----------|------|
| 1 | `aws_vpc` | `main` | VPC |
| 2 | `aws_subnet` | `public_1` | パブリックサブネット (AZ-a) |
| 3 | `aws_subnet` | `public_2` | パブリックサブネット (AZ-c) |
| 4 | `aws_internet_gateway` | `main` | インターネットゲートウェイ |
| 5 | `aws_route_table` | `public` | パブリックルートテーブル |
| 6 | `aws_route_table_association` | `public_1` | サブネット 1 とルートテーブルの関連付け |
| 7 | `aws_route_table_association` | `public_2` | サブネット 2 とルートテーブルの関連付け |
| 8 | `aws_security_group` | `alb` | ALB 用セキュリティグループ |
| 9 | `aws_security_group` | `ecs_tasks` | ECS タスク用セキュリティグループ |
| 10 | `aws_lb` | `main` | Application Load Balancer |
| 11 | `aws_lb_target_group` | `app` | ALB ターゲットグループ |
| 12 | `aws_lb_listener` | `http` | ALB リスナー (HTTP:80) |
| 13 | `aws_ecr_repository` | `app` | Docker イメージリポジトリ |
| 14 | `aws_ecs_cluster` | `main` | ECS クラスター |
| 15 | `aws_ecs_task_definition` | `app` | ECS タスク定義 |
| 16 | `aws_ecs_service` | `app` | ECS サービス |
| 17 | `aws_iam_role` | `ecs_task_execution` | ECS タスク実行ロール |
| 18 | `aws_iam_role` | `ecs_task` | ECS タスクロール |
| 19 | `aws_iam_role_policy_attachment` | `ecs_task_execution` | タスク実行ロールへのポリシーアタッチ |
| 20 | `aws_cloudwatch_log_group` | `app` | コンテナログ用ロググループ |

## 2. ファイル構成

```
infra/
├── main.tf          # Provider 設定、VPC、サブネット、IGW、ルートテーブル
├── alb.tf           # ALB、ターゲットグループ、リスナー
├── ecr.tf           # ECR リポジトリ
├── ecs.tf           # ECS クラスター、タスク定義、サービス
├── iam.tf           # IAM ロール、ポリシー
├── security_groups.tf  # セキュリティグループ
├── logs.tf          # CloudWatch ロググループ
├── variables.tf     # 入力変数
├── outputs.tf       # 出力値
└── terraform.tfvars # 変数値（Git 管理対象）
```

## 3. リソース詳細設計

### 3.1 VPC / ネットワーク（main.tf）

```
Provider: aws
Region: ap-northeast-1

VPC:
  CIDR: 10.0.0.0/16
  DNS Support: true
  DNS Hostnames: true

Public Subnet 1:
  CIDR: 10.0.1.0/24
  AZ: ap-northeast-1a
  Map Public IP: true

Public Subnet 2:
  CIDR: 10.0.2.0/24
  AZ: ap-northeast-1c
  Map Public IP: true

Internet Gateway: VPC に attach

Route Table (public):
  Route: 0.0.0.0/0 → Internet Gateway
  Association: Public Subnet 1, Public Subnet 2
```

### 3.2 セキュリティグループ（security_groups.tf）

**ALB セキュリティグループ:**

| 方向 | プロトコル | ポート | ソース/宛先 |
|------|-----------|--------|-------------|
| Ingress | TCP | 80 | 0.0.0.0/0 |
| Egress | All | All | 0.0.0.0/0 |

**ECS タスクセキュリティグループ:**

| 方向 | プロトコル | ポート | ソース/宛先 |
|------|-----------|--------|-------------|
| Ingress | TCP | 8000 | ALB SG |
| Egress | All | All | 0.0.0.0/0 |

### 3.3 ALB（alb.tf）

```
ALB:
  Type: application
  Scheme: internet-facing
  Subnets: Public Subnet 1, Public Subnet 2
  Security Group: ALB SG

Target Group:
  Port: 8000
  Protocol: HTTP
  Target Type: ip
  Health Check:
    Path: /health
    Interval: 30s
    Timeout: 5s
    Healthy Threshold: 2
    Unhealthy Threshold: 3
    Matcher: 200

Listener:
  Port: 80
  Protocol: HTTP
  Default Action: forward to Target Group
```

### 3.4 ECR（ecr.tf）

```
ECR Repository:
  Name: sample-cicd
  Image Tag Mutability: MUTABLE (latest タグ更新のため)
  Image Scanning: ON_PUSH (プッシュ時スキャン有効)
  Lifecycle Policy: 未タグイメージを 7 日後に削除
```

### 3.5 ECS（ecs.tf）

```
ECS Cluster:
  Name: sample-cicd

Task Definition:
  Family: sample-cicd
  CPU: 256
  Memory: 512
  Network Mode: awsvpc
  Requires Compatibilities: FARGATE
  Execution Role: ecs_task_execution role
  Task Role: ecs_task role
  Container:
    Name: app
    Image: <ECR_URI>:latest
    Port: 8000
    Log Configuration:
      Driver: awslogs
      Options:
        awslogs-group: /ecs/sample-cicd
        awslogs-region: ap-northeast-1
        awslogs-stream-prefix: app

ECS Service:
  Name: sample-cicd
  Cluster: sample-cicd
  Task Definition: sample-cicd
  Desired Count: 1
  Launch Type: FARGATE
  Network Configuration:
    Subnets: Public Subnet 1, Public Subnet 2
    Security Groups: ECS Tasks SG
    Assign Public IP: true
  Load Balancer:
    Target Group: app
    Container Name: app
    Container Port: 8000
  Deployment:
    Minimum Healthy Percent: 100
    Maximum Percent: 200
```

### 3.6 IAM（iam.tf）

**ECS タスク実行ロール（ecs_task_execution）:**

| ポリシー | 用途 |
|----------|------|
| `AmazonECSTaskExecutionRolePolicy` (AWS 管理) | ECR からのイメージ pull、CloudWatch Logs への書き込み |

Trust Policy: `ecs-tasks.amazonaws.com`

**ECS タスクロール（ecs_task）:**

| ポリシー | 用途 |
|----------|------|
| (なし) | 現時点では AWS サービスへのアクセス不要 |

Trust Policy: `ecs-tasks.amazonaws.com`

### 3.7 CloudWatch Logs（logs.tf）

```
Log Group:
  Name: /ecs/sample-cicd
  Retention: 14 days
```

## 4. 変数設計（variables.tf）

| 変数名 | 型 | デフォルト値 | 説明 |
|--------|----|-------------|------|
| `project_name` | string | `"sample-cicd"` | プロジェクト名 |
| `aws_region` | string | `"ap-northeast-1"` | AWS リージョン |
| `vpc_cidr` | string | `"10.0.0.0/16"` | VPC CIDR |
| `app_port` | number | `8000` | アプリケーションポート |
| `fargate_cpu` | number | `256` | Fargate CPU |
| `fargate_memory` | number | `512` | Fargate メモリ |
| `desired_count` | number | `1` | ECS タスク数 |

## 5. 出力値設計（outputs.tf）

| 出力名 | 説明 |
|--------|------|
| `alb_dns_name` | ALB の DNS 名（アクセス URL） |
| `ecr_repository_url` | ECR リポジトリの URL |
| `ecs_cluster_name` | ECS クラスター名 |
| `ecs_service_name` | ECS サービス名 |

## 6. タグ付けルール

すべてのリソースに以下のタグを付与する（CLAUDE.md 準拠）:

| タグキー | 値 |
|----------|------|
| `Project` | `sample-cicd` |

`default_tags` ブロックを provider 設定で定義し、全リソースに自動適用する。

## 7. State 管理

| 項目 | 値 |
|------|------|
| Backend | local（学習用のためリモートバックエンドは使用しない） |
| State file | `infra/terraform.tfstate` |
| `.gitignore` | `*.tfstate`, `*.tfstate.backup`, `.terraform/` を追加 |
