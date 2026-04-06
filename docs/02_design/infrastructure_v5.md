# Terraform リソース設計書 (v5)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-06 |
| バージョン | 5.0 |
| 前バージョン | [infrastructure_v4.md](infrastructure_v4.md) (v4.0) |

## 変更概要

v4 の 63 アクティブリソースに以下を追加する:

- **新規ファイル**: `s3.tf`, `cloudfront.tf`, `dev.tfvars`, `prod.tfvars`
- **変更ファイル**: `main.tf`（locals ブロック追加）、全 `.tf` ファイル（`${var.project_name}` → `${local.prefix}` に変更）、`iam.tf`（S3 ポリシー追加）、`ecs.tf`（環境変数追加）、`variables.tf`（v5 変数追加）、`outputs.tf`（S3 / CloudFront 出力追加）
- **削除ファイル**: `terraform.tfvars`（`dev.tfvars` / `prod.tfvars` に分離）
- **追加リソース数**: 8 リソース
- **Workspace 対応**: 全リソース名に `${local.env}` を含める

デプロイ後のアクティブリソース: 63 + 8 = **71 リソース**（dev 環境）

## 1. Terraform リソース一覧

### v4 から継続（63 リソース）

（v4 の一覧と同一。詳細は [infrastructure_v4.md](infrastructure_v4.md) を参照）

> **重要変更**: 全リソースの `name` が `sample-cicd-{リソース名}` → `sample-cicd-dev-{リソース名}` に変更される。
> 機能的な変更はなく、命名規則の変更のみ。

### v5 新規（8 リソース）

#### s3.tf（4 リソース）

| # | リソースタイプ | リソース��� | 用途 |
|---|--------------|-----------|------|
| 64 | `aws_s3_bucket` | `attachments` | ファイル添付ストレージ |
| 65 | `aws_s3_bucket_public_access_block` | `attachments` | パブリックアクセス全ブロック |
| 66 | `aws_s3_bucket_policy` | `attachments` | CloudFront OAC のみ `s3:GetObject` を許可 |
| 67 | `aws_s3_bucket_cors_configuration` | `attachments` | Presigned URL アップロード用 CORS 設定 |

#### cloudfront.tf（4 リソース）

| # | リソースタイプ | リソース名 | 用途 |
|---|--------------|-----------|------|
| 68 | `aws_cloudfront_origin_access_control` | `s3` | CloudFront → S3 の OAC 認証 |
| 69 | `aws_cloudfront_distribution` | `attachments` | CDN ディストリビューション |
| 70 | `aws_cloudfront_cache_policy` | `attachments` | キャッシュポリシー（デフォルト TTL） |
| 71 | `data.aws_cloudfront_cache_policy` | `caching_optimized` | AWS マネージドキャッシュポリシー参照 |

> **既存リソース変更（リソース数に含めない）:**
> - `aws_iam_role_policy.ecs_task` に S3 PutObject / DeleteObject ポリシーを追加
> - `aws_ecs_task_definition.app` に `S3_BUCKET_NAME`, `CLOUDFRONT_DOMAIN_NAME` 環境変数を追加
> - 全リソースの `name` / `tags` を `${local.prefix}` に変更

## 2. ファイル構成

```
infra/
├── main.tf              [変更: locals ブロック追加、全リソース名を ${local.prefix} に]
├── alb.tf               [変更: リソース名を ${local.prefix} に]
├── ecr.tf               [変更: リソース名を ${local.prefix} に]
├── ecs.tf               [変更: リソース名 + 環境変数 S3_BUCKET_NAME / CLOUDFRONT_DOMAIN_NAME 追加]
├���─ iam.tf               [変更: リソース名 + ECS タスクロールに S3 権限追加]
├── security_groups.tf   [変更: リソース名を ${local.prefix} に]
├── logs.tf              [変更: リソース名を ${local.prefix} に]
├─�� rds.tf               [変更: リソース名を ${local.prefix} に]
├── secrets.tf           [変更: リソース名を ${local.prefix} に]
├── autoscaling.tf       [変更なし（リソース名は ARN 参照のため固定）]
���── https.tf             [変更: リソース名を ${local.prefix} に]
├── sqs.tf               [変更: リソース名を ${local.prefix} に]
├── lambda.tf            [変更: リソース名を ${local.prefix} に]
├── eventbridge.tf       [変更: リソース名を ${local.prefix} に]
├── vpc_endpoints.tf     [変更: リソース名を ${local.prefix} に]
├── s3.tf                [新規: S3 バケット + ポリシー + CORS]
├── cloudfront.tf        [新規: CloudFront ディストリビューション + OAC]
├── variables.tf         [変更: v5 変数追加]
├── outputs.tf           [変更: S3 / CloudFront 出力追加]
├── dev.tfvars           [新規: dev 環境パラメータ]
└── prod.tfvars          [新規: prod 環境パラメータ]
    (terraform.tfvars は削除)
```

## 3. Workspace 対応設計

### 3.1 locals ブロック（main.tf に追加）

```hcl
locals {
  env    = terraform.workspace
  prefix = "${var.project_name}-${local.env}"
}
```

### 3.2 リソース名の変更例

```hcl
# Before (v4):
resource "aws_security_group" "alb" {
  name = "${var.project_name}-alb-sg"
  tags = { Name = "${var.project_name}-alb-sg", Project = var.project_name }
}

# After (v5):
resource "aws_security_group" "alb" {
  name = "${local.prefix}-alb-sg"
  tags = { Name = "${local.prefix}-alb-sg", Project = var.project_name, Environment = local.env }
}
```

> **設計判断 - `Environment` タグの追加:**
> 全リソースに `Environment = local.env` タグを追加し、
> AWS コンソールやコスト管理で環境ごとにフィルタリングできるようにする。

### 3.3 Workspace ごとの tfstate

```
infra/
├── terraform.tfstate.d/
│   ├── dev/
│   │   └── terraform.tfstate    # dev 環境の状態
│   └── prod/
│       └── terraform.tfstate    # prod 環境の状態（未使用）
```

## 4. 新規リソース詳細設計

### 4.1 s3.tf

```hcl
# S3 バケット
aws_s3_bucket "attachments":
  bucket = "${local.prefix}-attachments"
  tags   = { Project = var.project_name, Environment = local.env }

# パブリックアクセス全ブロック
aws_s3_bucket_public_access_block "attachments":
  bucket                  = aws_s3_bucket.attachments.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

# バケットポリシー（CloudFront OAC のみ GetObject 許可）
aws_s3_bucket_policy "attachments":
  bucket = aws_s3_bucket.attachments.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.attachments.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.attachments.arn
        }
      }
    }]
  })

# CORS 設定（Presigned URL アップロード用）
aws_s3_bucket_cors_configuration "attachments":
  bucket = aws_s3_bucket.attachments.id
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT"]
    allowed_origins = ["*"]    # dev 環境では全オリジン許可
    max_age_seconds = 3600
  }
```

> **設計判断 - CORS `allowed_origins = ["*"]`:**
> 学習用途のため全オリジンを許可する。本番では ALB DNS 名や独自ドメインに限定すべき。

> **設計判断 - S3 バケットのバージョニング不使用:**
> 添付ファイルはイミュータブル（UUID + ファイル名でキーを生成）のため、
> 同じキーへの上書きは発生しない。バージョニングは不要。

### 4.2 cloudfront.tf

```hcl
# Origin Access Control
aws_cloudfront_origin_access_control "s3":
  name                              = "${local.prefix}-s3-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"

# CloudFront ディストリビューション
aws_cloudfront_distribution "attachments":
  enabled             = true
  default_root_object = ""
  price_class         = var.cloudfront_price_class
  comment             = "${local.prefix} attachments CDN"

  origin {
    domain_name              = aws_s3_bucket.attachments.bucket_regional_domain_name
    origin_id                = "s3-attachments"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-attachments"
    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true    # デフォルト *.cloudfront.net 証明書
  }

  tags = { Project = var.project_name, Environment = local.env }

# AWS マネージドキャッシュポリシー参照
data "aws_cloudfront_cache_policy" "caching_optimized":
  name = "Managed-CachingOptimized"
```

> **設計判断 - `Managed-CachingOptimized` キャッシュポリシー:**
> AWS が提供するマネージドポリシー。TTL 86400 秒（24 時間）、圧縮対応。
> カスタムポリシーを作成する代わりに参照のみで利用し、設計をシンプルに保つ。

> **設計判断 - `allowed_methods = ["GET", "HEAD"]`:**
> ダウンロード専用。アップロードは Presigned URL で S3 に直接行うため、
> CloudFront を経由する PUT/POST は不要。

> **設計判断 - `cloudfront_default_certificate`:**
> カスタムドメイン / HTTPS は v3 同様コードのみとし、デフォルトの `*.cloudfront.net` ドメインを使用する。

## 5. 既存ファイル変更詳細

### 5.1 main.tf（locals ブロック追加）

```hcl
# 追加
locals {
  env    = terraform.workspace
  prefix = "${var.project_name}-${local.env}"
}

# 全リソースの name / tags を ${local.prefix} に変更
# 例:
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name        = "${local.prefix}-vpc"
    Project     = var.project_name
    Environment = local.env
  }
}
```

### 5.2 ecs.tf（環境変数追加）

```hcl
# aws_ecs_task_definition.app の container_definitions に追加
environment = [
  ...既存の環境変数,
  { name = "S3_BUCKET_NAME",         value = aws_s3_bucket.attachments.bucket },
  { name = "CLOUDFRONT_DOMAIN_NAME", value = aws_cloudfront_distribution.attachments.domain_name },
]
```

### 5.3 iam.tf（ECS タスクロールに S3 ポリシー追加）

```hcl
# 既存の aws_iam_role_policy.ecs_task に追記
Statement: [
  ...既存のポリシー,
  {
    Effect   = "Allow"
    Action   = ["s3:PutObject", "s3:DeleteObject"]
    Resource = ["${aws_s3_bucket.attachments.arn}/*"]
  }
]
```

> `s3:GetObject` は不要。ダウンロードは CloudFront OAC が S3 に対して行い、
> ECS タスクは CloudFront URL を返すのみ。

### 5.4 outputs.tf（v5 出力追加）

```hcl
output "s3_bucket_name" {
  value = aws_s3_bucket.attachments.bucket
}
output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.attachments.domain_name
}
output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.attachments.id
}
```

## 6. 変数設計（variables.tf 変更）

### v5 追加変数

| 変数名 | 型 | デフォルト値 | 説明 |
|--------|----|-------------|------|
| `cloudfront_price_class` | string | `"PriceClass_100"` | CloudFront の Price Class |
| `upload_presigned_url_expiry` | number | `300` | Presigned URL の有効期限（秒） |
| `allowed_content_types` | list(string) | `["image/jpeg","image/png","image/gif","application/pdf","text/plain"]` | 許可するファイルタイプ |
| `max_file_size_mb` | number | `10` | アップロード最大ファイルサイズ（MB） |

### 既存変数の環境別化（dev.tfvars / prod.tfvars で上書き）

| 変数名 | dev.tfvars | prod.tfvars |
|--------|-----------|-------------|
| `fargate_cpu` | 256 | 512 |
| `fargate_memory` | 512 | 1024 |
| `desired_count` | 1 | 2 |
| `ecs_min_count` | 1 | 2 |
| `ecs_max_count` | 2 | 4 |
| `db_instance_class` | "db.t3.micro" | "db.t3.small" |
| `db_multi_az` | false | true |
| `cloudfront_price_class` | "PriceClass_100" | "PriceClass_200" |
| `log_retention_days` | 7 | 30 |
| `lambda_log_retention_days` | 7 | 30 |

## 7. リソース依存関係（v5 追加分）

```
# S3 + CloudFront フロー
aws_s3_bucket.attachments
  └──▶ aws_s3_bucket_public_access_block.attachments
  └──▶ aws_s3_bucket_cors_configuration.attachments
  └──▶ aws_cloudfront_origin_access_control.s3
         └──▶ aws_cloudfront_distribution.attachments
                └──▶ aws_s3_bucket_policy.attachments (CloudFront ARN を参照)

# ECS → S3 権限
aws_s3_bucket.attachments
  └──▶ aws_iam_role_policy.ecs_task (S3 PutObject / DeleteObject)
```

## 8. State 管理（変更あり）

| 項目 | 値 |
|------|------|
| Backend | local |
| State file | `infra/terraform.tfstate.d/{workspace}/terraform.tfstate` |
| Workspace | `dev`（実デプロイ）、`prod`（tfvars のみ） |

> v4 では `infra/terraform.tfstate` 単体だった��、v5 では Workspace ごとに分離。
> `.gitignore` に `terraform.tfstate.d/` は既に `*.tfstate` パターンで除外済み。
