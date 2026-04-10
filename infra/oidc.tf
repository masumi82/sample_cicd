# --- v9: OIDC Authentication (GitHub Actions → AWS) ---

# GitHub OIDC Provider
resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # GitHub OIDC thumbprint — AWS ignores this for GitHub but it's required by the API
  thumbprint_list = ["ffffffffffffffffffffffffffffffffffffffff"]

  tags = {
    Name        = "${local.prefix}-github-oidc"
    Project     = var.project_name
    Environment = local.env
  }
}

# GitHub Actions IAM Role
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

# GitHub Actions Role Policy
resource "aws_iam_role_policy" "github_actions" {
  name = "${local.prefix}-github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ECR — login
      {
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      # ECR — push images
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
      # ECS — task definition + service
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
      # CodeDeploy — create and monitor deployments
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
      # IAM PassRole — ECS task roles
      {
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = [
          aws_iam_role.ecs_task_execution.arn,
          aws_iam_role.ecs_task.arn
        ]
      },
      # Lambda — update function code
      {
        Effect   = "Allow"
        Action   = "lambda:UpdateFunctionCode"
        Resource = "arn:aws:lambda:${var.aws_region}:*:function:${local.prefix}-*"
      },
      # S3 — webui deployment
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
      # CloudFront — cache invalidation + list
      {
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation",
          "cloudfront:ListDistributions"
        ]
        Resource = "*"
      },
      # ELB — describe for deployment
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTargetGroups"
        ]
        Resource = "*"
      },
      # Cognito — config.js generation
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:ListUserPools",
          "cognito-idp:ListUserPoolClients"
        ]
        Resource = "*"
      },
      # Terraform State — S3 backend
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
      # Terraform State — DynamoDB lock
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:${var.aws_region}:*:table/sample-cicd-tflock"
      },
      # Terraform apply — broad permissions for managed resources (region-scoped)
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
          "application-autoscaling:*",
          "lambda:*",
          "s3:*",
          "cloudfront:*",
          "codedeploy:*",
          "elasticloadbalancing:*",
          "ecr:*",
          "ecs:*",
          "scheduler:*",
          "apigateway:*",
          "elasticache:*",
          "backup:*",
          "backup-storage:*",
          "cloudtrail:*",
          "guardduty:*",
          "config:*",
          "securityhub:*",
          "kms:CreateGrant",
          "kms:GenerateDataKey",
          "kms:Decrypt",
          "kms:RetireGrant",
          "kms:DescribeKey",
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      }
    ]
  })
}
