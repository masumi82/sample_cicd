# Terraform リソース設計書 (v9)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-08 |
| バージョン | 9.0 |
| 前バージョン | [infrastructure_v8.md](infrastructure_v8.md) (v8.0) |

## 変更概要

v8 の 93 アクティブリソース（dev 環境）に以下を変更・追加する:

- **新規ファイル**: `infra/codedeploy.tf`（CodeDeploy アプリケーション + デプロイグループ）、`infra/oidc.tf`（OIDC プロバイダー + GitHub Actions IAM ロール）
- **変更ファイル**: `alb.tf`（Blue/Green TG 追加）、`ecs.tf`（deployment_controller 変更）、`iam.tf`（CodeDeploy サービスロール追加）、`variables.tf`（新変数追加）、`dev.tfvars`（新変数追加）、`monitoring.tf`（TG 参照更新）
- **追加リソース数**: 約 10 リソース
- **削除リソース数**: 1 リソース（既存 `aws_lb_target_group.app` → Blue/Green に置換）
- **主要変更**: B/G デプロイ基盤、OIDC 認証基盤

デプロイ後のアクティブリソース: 93 - 1 + 10 = **約 102 リソース**（dev 環境）

> **注**: ECS サービスは `deployment_controller` を後から変更できないため、再作成が必要。

## 1. Terraform リソース一覧

### v8 から継続（93 リソース）

（v8 の一覧と同一。詳細は [infrastructure_v8.md](infrastructure_v8.md) を参照）

> **重要変更**:
> - `alb.tf` の `aws_lb_target_group.app` を `aws_lb_target_group.blue` にリネーム + Green TG を追加
> - `ecs.tf` の `aws_ecs_service.app` に `deployment_controller { type = "CODE_DEPLOY" }` を追加
> - `iam.tf` に CodeDeploy サービスロールを追加

### v9 新規: codedeploy.tf（3 リソース）

| # | リソースタイプ | リソース名 | 用途 |
|---|--------------|-----------|------|
| 1 | `aws_codedeploy_app` | `main` | CodeDeploy アプリケーション（ECS コンピューティングプラットフォーム） |
| 2 | `aws_codedeploy_deployment_group` | `main` | B/G デプロイグループ（自動ロールバック、Blue 5分後に終了） |
| 3 | `aws_iam_role` | `codedeploy` | CodeDeploy サービスロール |

### v9 新規: oidc.tf（3 リソース）

| # | リソースタイプ | リソース名 | 用途 |
|---|--------------|-----------|------|
| 4 | `aws_iam_openid_connect_provider` | `github_actions` | GitHub OIDC プロバイダー |
| 5 | `aws_iam_role` | `github_actions` | GitHub Actions 用 IAM ロール（OIDC 信頼ポリシー） |
| 6 | `aws_iam_role_policy` | `github_actions` | GitHub Actions ロールのインラインポリシー |

### v9 変更: alb.tf（+1 リソース、1 リネーム）

| # | リソースタイプ | リソース名 | 変更 |
|---|--------------|-----------|------|
| 7 | `aws_lb_target_group` | `blue` | 既存 `app` をリネーム。Blue（本番）トラフィック用 |
| 8 | `aws_lb_target_group` | `green` | **新規**。Green（新バージョン）テスト用 |

### v9 変更: iam.tf（+2 リソース）

| # | リソースタイプ | リソース名 | 用途 |
|---|--------------|-----------|------|
| 9 | `aws_iam_role_policy_attachment` | `codedeploy_ecs` | CodeDeploy ロールに `AWSCodeDeployRoleForECS` をアタッチ |
| 10 | `data.aws_iam_policy_document` | `github_actions_trust` | OIDC 信頼ポリシー（data source、リソースカウント外） |

## 2. ファイル構成

### 2.1 新規ファイル: infra/codedeploy.tf

```hcl
# --- v9: CodeDeploy Blue/Green Deployment ---

resource "aws_codedeploy_app" "main" {
  compute_platform = "ECS"
  name             = local.prefix

  tags = {
    Name        = "${local.prefix}-codedeploy"
    Project     = var.project_name
    Environment = local.env
  }
}

resource "aws_codedeploy_deployment_group" "main" {
  app_name               = aws_codedeploy_app.main.name
  deployment_group_name  = "${local.prefix}-dg"
  deployment_config_name = "CodeDeployDefault.ECS${var.codedeploy_traffic_routing}"
  service_role_arn       = aws_iam_role.codedeploy.arn

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.main.name
    service_name = aws_ecs_service.app.name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.http.arn]
      }

      target_group {
        name = aws_lb_target_group.blue.name
      }

      target_group {
        name = aws_lb_target_group.green.name
      }
    }
  }

  tags = {
    Name        = "${local.prefix}-deployment-group"
    Project     = var.project_name
    Environment = local.env
  }
}
```

### 2.2 新規ファイル: infra/oidc.tf

```hcl
# --- v9: OIDC Authentication (GitHub Actions → AWS) ---

# GitHub OIDC Provider
resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # GitHub OIDC の thumbprint（GitHub 公式値）
  thumbprint_list = ["ffffffffffffffffffffffffffffffffffffffff"]

  tags = {
    Name        = "${local.prefix}-github-oidc"
    Project     = var.project_name
    Environment = local.env
  }
}

# GitHub Actions 用 IAM ロール
resource "aws_iam_role" "github_actions" {
  name = "${local.prefix}-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${local.prefix}-github-actions"
    Project     = var.project_name
    Environment = local.env
  }
}

# GitHub Actions ロールのポリシー
resource "aws_iam_role_policy" "github_actions" {
  name = "${local.prefix}-github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ECR
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:BatchGetImage"
        ]
        Resource = aws_ecr_repository.app.arn
      },
      # ECS
      {
        Effect = "Allow"
        Action = [
          "ecs:RegisterTaskDefinition",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeServices",
          "ecs:UpdateService"
        ]
        Resource = "*"
      },
      # CodeDeploy
      {
        Effect = "Allow"
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:GetApplicationRevision",
          "codedeploy:RegisterApplicationRevision"
        ]
        Resource = "*"
      },
      # IAM PassRole (ECS task execution/task roles + CodeDeploy role)
      {
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = [
          aws_iam_role.ecs_task_execution.arn,
          aws_iam_role.ecs_task.arn
        ]
      },
      # Lambda
      {
        Effect = "Allow"
        Action = "lambda:UpdateFunctionCode"
        Resource = "arn:aws:lambda:${var.aws_region}:*:function:${local.prefix}-*"
      },
      # S3 (webui)
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${local.prefix}-webui",
          "arn:aws:s3:::${local.prefix}-webui/*"
        ]
      },
      # CloudFront
      {
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation",
          "cloudfront:ListDistributions"
        ]
        Resource = "*"
      },
      # ELB (for deployment)
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTargetGroups"
        ]
        Resource = "*"
      },
      # Cognito (for config.js generation)
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:ListUserPools",
          "cognito-idp:ListUserPoolClients"
        ]
        Resource = "*"
      },
      # Terraform State (S3 + DynamoDB)
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::sample-cicd-tfstate",
          "arn:aws:s3:::sample-cicd-tfstate/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:${var.aws_region}:*:table/sample-cicd-tflock"
      },
      # Terraform apply needs broad permissions for managed resources
      # Scoped to project-prefixed resources where possible
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "rds:*",
          "sqs:*",
          "events:*",
          "sns:*",
          "cloudwatch:*",
          "logs:*",
          "secretsmanager:*",
          "cognito-idp:*",
          "wafv2:*",
          "acm:*",
          "route53:*",
          "iam:*",
          "application-autoscaling:*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = [var.aws_region, "us-east-1"]
          }
        }
      }
    ]
  })
}
```

> **設計判断 - Terraform apply 用の広範な権限について:**
> `terraform apply` は管理対象の全リソースに対する CRUD 権限が必要。
> 学習用プロジェクトのため、リージョン制限（`ap-northeast-1` + `us-east-1`）で
> スコープを限定する。本番環境では Resource ARN で厳密に制限すべき。

### 2.3 変更ファイル: alb.tf

```hcl
# Target Group — Blue (production traffic)
resource "aws_lb_target_group" "blue" {
  name        = "${local.prefix}-tg-blue"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = {
    Name        = "${local.prefix}-tg-blue"
    Project     = var.project_name
    Environment = local.env
  }
}

# Target Group — Green (new version)
resource "aws_lb_target_group" "green" {
  name        = "${local.prefix}-tg-green"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = {
    Name        = "${local.prefix}-tg-green"
    Project     = var.project_name
    Environment = local.env
  }
}

# HTTP Listener — Blue TG を初期ターゲットに
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }

  tags = {
    Name = "${local.prefix}-http-listener"
  }

  # CodeDeploy がリスナーのターゲットグループを切り替えるため、
  # Terraform の差分検出で無限ループしないよう ignore する
  lifecycle {
    ignore_changes = [default_action]
  }
}
```

> **設計判断 - `ignore_changes = [default_action]` について:**
> CodeDeploy が B/G デプロイ時にリスナーのターゲットグループを Blue → Green に切り替える。
> `terraform plan` でこの変更が差分として検出され、毎回 `default_action` の変更が提案される。
> これを防ぐため `lifecycle { ignore_changes }` を設定する。

### 2.4 変更ファイル: ecs.tf

```hcl
# ECS Service — 変更箇所のみ
resource "aws_ecs_service" "app" {
  name            = local.prefix
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_1.id, aws_subnet.public_2.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.blue.arn  # Blue TG に変更
    container_name   = "app"
    container_port   = var.app_port
  }

  # v9: CodeDeploy B/G deployment
  deployment_controller {
    type = "CODE_DEPLOY"
  }

  # CodeDeploy が task_definition を管理するため、Terraform の差分検出を無効化
  lifecycle {
    ignore_changes = [task_definition, load_balancer]
  }

  depends_on = [aws_lb_listener.http]

  tags = {
    Name = "${local.prefix}-service"
  }
}
```

> **設計判断 - `ignore_changes = [task_definition, load_balancer]` について:**
> CodeDeploy B/G デプロイでは、task_definition と load_balancer (target_group) の更新は
> CodeDeploy が管理する。Terraform がこれらを管理しようとすると CodeDeploy と競合するため、
> `lifecycle { ignore_changes }` で除外する。

> **注意**: 既存の ECS サービスは `deployment_controller` を変更できない。
> 移行手順は「4. デプロイ手順」を参照。

### 2.5 変更ファイル: iam.tf（追加分）

```hcl
# --- v9: CodeDeploy Service Role ---

resource "aws_iam_role" "codedeploy" {
  name = "${local.prefix}-codedeploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "codedeploy.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${local.prefix}-codedeploy"
    Project     = var.project_name
    Environment = local.env
  }
}

resource "aws_iam_role_policy_attachment" "codedeploy_ecs" {
  role       = aws_iam_role.codedeploy.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}
```

### 2.6 変更ファイル: variables.tf（追加分）

```hcl
# --- v9: CI/CD Automation ---

variable "github_repo" {
  description = "GitHub repository (owner/repo format) for OIDC trust policy"
  type        = string
}

variable "codedeploy_traffic_routing" {
  description = "CodeDeploy traffic routing type (AllAtOnce or Linear10PercentEvery1Minute)"
  type        = string
  default     = "AllAtOnce"
}

variable "enable_test_listener" {
  description = "Create test listener on port 8080 for B/G deployment testing"
  type        = bool
  default     = false
}
```

### 2.7 変更ファイル: dev.tfvars（追加分）

```hcl
# --- v9: CI/CD Automation ---
github_repo                = "masumi82/sample_cicd"
codedeploy_traffic_routing = "AllAtOnce"
enable_test_listener       = false
```

### 2.8 変更ファイル: prod.tfvars（追加分）

```hcl
# --- v9: CI/CD Automation ---
github_repo                = "masumi82/sample_cicd"
codedeploy_traffic_routing = "AllAtOnce"
enable_test_listener       = false
```

### 2.9 変更ファイル: monitoring.tf

ターゲットグループ参照を `aws_lb_target_group.app` → `aws_lb_target_group.blue` に更新する。

```hcl
# HealthyHostCount / UnHealthyHostCount のアラームで参照
# 変更前: aws_lb_target_group.app.arn_suffix
# 変更後: aws_lb_target_group.blue.arn_suffix
```

## 3. リソース依存関係

```
# OIDC (独立)
aws_iam_openid_connect_provider.github_actions
  └── aws_iam_role.github_actions (信頼ポリシーで OIDC Provider 参照)
       └── aws_iam_role_policy.github_actions

# CodeDeploy
aws_iam_role.codedeploy
  └── aws_iam_role_policy_attachment.codedeploy_ecs
aws_codedeploy_app.main
  └── aws_codedeploy_deployment_group.main
       ├── aws_ecs_service.app (ecs_service ブロック)
       ├── aws_lb_listener.http (prod_traffic_route)
       ├── aws_lb_target_group.blue (target_group)
       └── aws_lb_target_group.green (target_group)

# ALB Target Groups
aws_lb_target_group.blue
  ├── aws_lb_listener.http (default_action)
  └── aws_ecs_service.app (load_balancer)
aws_lb_target_group.green
  └── aws_codedeploy_deployment_group.main (target_group)

# ECS Service (再作成)
aws_ecs_service.app
  └── deployment_controller { type = "CODE_DEPLOY" }
```

## 4. デプロイ手順

v9 のデプロイは以下の順序で行う（ECS サービスの再作成が必要）:

```
Step 1: OIDC Provider + IAM ロール作成
  cd infra
  # oidc.tf + iam.tf (CodeDeploy role) を追加
  terraform plan -var-file=dev.tfvars
  terraform apply -var-file=dev.tfvars
  # → OIDC Provider + GitHub Actions ロール + CodeDeploy ロール作成

Step 2: GitHub Secrets 更新
  # GitHub Secrets に AWS_OIDC_ROLE_ARN を追加
  # GitHub Secrets に INFRACOST_API_KEY を追加（事前に Infracost 登録）

Step 3: ALB Target Group + CodeDeploy リソース作成
  # alb.tf (Blue/Green TG) + codedeploy.tf を追加
  # ただし ECS サービスは deployment_controller 変更のため再作成が必要

Step 4: ECS サービス再作成
  # 方法: terraform state rm → ECS サービス削除 → terraform apply
  terraform state rm aws_ecs_service.app
  aws ecs update-service --cluster sample-cicd-dev --service sample-cicd-dev --desired-count 0
  aws ecs delete-service --cluster sample-cicd-dev --service sample-cicd-dev
  # 旧 TG も state rm
  terraform state rm aws_lb_target_group.app
  terraform apply -var-file=dev.tfvars
  # → 新 ECS サービス (CODE_DEPLOY) + Blue/Green TG + CodeDeploy が作成

Step 5: ワークフロー分割 + OIDC 移行
  # ci-cd.yml を削除し、ci.yml + cd.yml を作成
  # git push → CI/CD が新ワークフローで動作確認

Step 6: Access Key 廃止
  # GitHub Secrets から AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY を削除
  # IAM ユーザーの Access Key を無効化
```

## 5. コスト影響

| リソース | 月額コスト |
|---------|----------|
| CodeDeploy | $0（ECS デプロイは無料） |
| IAM OIDC Provider | $0（IAM リソースは無料） |
| IAM ロール x 2 (GitHub Actions, CodeDeploy) | $0 |
| 追加 Target Group (Green) | $0（使用時のみ課金、学習用途ではほぼ $0） |
| **v9 追加合計** | **~$0/月** |
