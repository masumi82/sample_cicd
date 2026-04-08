# Terraform リソース設計書 (v8)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-07 |
| バージョン | 8.0 |
| 前バージョン | [infrastructure_v7.md](infrastructure_v7.md) (v7.0) |

## 変更概要

v7 の 95 アクティブリソースに以下を変更・追加する:

- **リネームファイル**: `https.tf` → `custom_domain.tf`（内容を全面書き換え）
- **変更ファイル**: `webui.tf`（aliases, viewer_certificate 追加）、`variables.tf`（`enable_https` 廃止、変数統一）、`outputs.tf`（カスタムドメイン URL 追加）、`dev.tfvars`（ドメイン設定有効化）、`prod.tfvars`（ドメイン設定追加）、`main.tf`（backend "s3" ブロック追加）
- **新規ディレクトリ**: `infra/bootstrap/`（Remote State 用 S3 + DynamoDB）
- **追加リソース数**: 4 リソース（custom_domain.tf）+ 3 リソース（bootstrap/）
- **削除リソース数**: 6 リソース（旧 https.tf のリソースをすべて削除・置換）
- **主要機能**: カスタムドメイン HTTPS、Remote State

デプロイ後のアクティブリソース: 95 - 6 + 4 = **93 リソース**（dev 環境、`enable_custom_domain = true`）

> **注**: v3 の https.tf は `enable_https = false`（デフォルト）で 0 リソースだったため、
> 実質的なリソース増減は +4（custom_domain.tf の新規リソース）。

## 1. Terraform リソース一覧

### v7 から継続（95 リソース）

（v7 の一覧と同一。詳細は [infrastructure_v7.md](infrastructure_v7.md) を参照）

> **重要変更**:
> - `https.tf` の全リソース（6 個）を削除し、`custom_domain.tf` に 4 リソースを新規作成
> - `webui.tf` の CloudFront ディストリビューションに `aliases` と `viewer_certificate` を追加
> - `main.tf` に `backend "s3"` ブロックを追加（Remote State）

### v8 変更: https.tf → custom_domain.tf（差し替え）

#### 削除リソース（旧 https.tf、6 リソース）

| リソースタイプ | リソース名 | 削除理由 |
|--------------|-----------|---------|
| `aws_acm_certificate` | `app` | CloudFront 用に us-east-1 で再作成 |
| `aws_route53_zone` | `app` | 既存 Hosted Zone を data source で参照に変更 |
| `aws_route53_record` | `acm_validation` | 新しい ACM 証明書の検証レコードに置換 |
| `aws_acm_certificate_validation` | `app` | 新しい ACM 証明書の検証に置換 |
| `aws_route53_record` | `app` | CloudFront への ALIAS に変更 |
| `aws_lb_listener` | `https` | CloudFront で TLS 終端のため ALB HTTPS リスナー不要 |

#### 新規リソース（custom_domain.tf、4 リソース）

| # | リソースタイプ | リソース名 | 用途 |
|---|--------------|-----------|------|
| 1 | `data.aws_route53_zone` | `main` | 既存 Hosted Zone の参照 |
| 2 | `aws_acm_certificate` | `cloudfront` | CloudFront 用 SSL/TLS 証明書（us-east-1） |
| 3 | `aws_route53_record` | `cert_validation` | ACM DNS 検証用 CNAME レコード |
| 4 | `aws_acm_certificate_validation` | `cloudfront` | ACM 検証完了待機 |
| 5 | `aws_route53_record` | `webui` | CloudFront への ALIAS レコード |

> **注**: `data.aws_route53_zone` はリソースではなくデータソースのため、Terraform リソースカウントには含まない。
> 実質 4 リソース（ACM 証明書、検証レコード、検証待機、ALIAS レコード）。

### v8 新規: bootstrap/（3 リソース、別ディレクトリ）

| # | リソースタイプ | リソース名 | 用途 |
|---|--------------|-----------|------|
| B1 | `aws_s3_bucket` | `tfstate` | Terraform state 保存用 S3 バケット |
| B2 | `aws_s3_bucket_versioning` | `tfstate` | State バケットのバージョニング有効化 |
| B3 | `aws_dynamodb_table` | `tflock` | State ロック用 DynamoDB テーブル |

> bootstrap リソースはメインの infra/ とは別管理（ローカル state）。

## 2. ファイル構成

### 2.1 新規ディレクトリ: infra/bootstrap/

#### bootstrap/main.tf

```hcl
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

# S3 bucket for Terraform state
resource "aws_s3_bucket" "tfstate" {
  bucket = "sample-cicd-tfstate"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Project = "sample-cicd"
    Purpose = "terraform-state"
  }
}

# Enable versioning for state recovery
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# DynamoDB table for state locking
resource "aws_dynamodb_table" "tflock" {
  name         = "sample-cicd-tflock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Project = "sample-cicd"
    Purpose = "terraform-lock"
  }
}
```

#### bootstrap/outputs.tf

```hcl
output "s3_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.tfstate.bucket
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.tflock.name
}
```

### 2.2 リネームファイル: https.tf → custom_domain.tf

```hcl
# --- v8: Custom Domain (HTTPS + Route 53) ---
#
# enable_custom_domain = true の場合に有効化。
# CloudFront に ACM 証明書とカスタムドメインを設定する。

# 既存の Hosted Zone を参照（Route 53 でドメイン購入時に自動作成済み）
data "aws_route53_zone" "main" {
  count   = var.enable_custom_domain ? 1 : 0
  zone_id = var.hosted_zone_id
}

# ACM 証明書（us-east-1、CloudFront の要件）
resource "aws_acm_certificate" "cloudfront" {
  count    = var.enable_custom_domain ? 1 : 0
  provider = aws.us_east_1

  domain_name               = "*.${data.aws_route53_zone.main[0].name}"
  subject_alternative_names = [data.aws_route53_zone.main[0].name]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${local.prefix}-cloudfront-cert"
    Project     = var.project_name
    Environment = local.env
  }
}

# ACM DNS 検証用 CNAME レコード
resource "aws_route53_record" "cert_validation" {
  for_each = var.enable_custom_domain ? {
    for dvo in aws_acm_certificate.cloudfront[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

# ACM 証明書の DNS 検証完了を待機
resource "aws_acm_certificate_validation" "cloudfront" {
  count    = var.enable_custom_domain ? 1 : 0
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.cloudfront[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# Route 53 ALIAS レコード（CloudFront ディストリビューションへ）
resource "aws_route53_record" "webui" {
  count   = var.enable_custom_domain ? 1 : 0
  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = var.custom_domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.webui.domain_name
    zone_id                = aws_cloudfront_distribution.webui.hosted_zone_id
    evaluate_target_health = false
  }
}
```

### 2.3 変更ファイル

#### webui.tf（変更箇所）

```hcl
resource "aws_cloudfront_distribution" "webui" {
  # ... 既存設定 ...

  # v8: カスタムドメイン設定（enable_custom_domain = true 時のみ）
  aliases = var.enable_custom_domain ? [var.custom_domain_name] : []

  # ... 既存設定 (origins, cache behaviors, etc.) ...

  # v8: viewer_certificate を動的に切り替え
  dynamic "viewer_certificate" {
    for_each = var.enable_custom_domain ? [] : [1]
    content {
      cloudfront_default_certificate = true
    }
  }

  dynamic "viewer_certificate" {
    for_each = var.enable_custom_domain ? [1] : []
    content {
      acm_certificate_arn      = aws_acm_certificate_validation.cloudfront[0].certificate_arn
      ssl_support_method       = "sni-only"
      minimum_protocol_version = "TLSv1.2_2021"
    }
  }

  # ... 既存設定 (restrictions, tags, etc.) ...
}
```

> **設計判断 - dynamic ブロックを使う理由:**
> `viewer_certificate` ブロックは `cloudfront_default_certificate` と `acm_certificate_arn` を
> 同時に指定できない。`enable_custom_domain` の値に応じて排他的に切り替える必要があるため、
> `dynamic` ブロックで条件分岐する。

#### main.tf（追加）

```hcl
terraform {
  # v8: Remote State (S3 + DynamoDB)
  backend "s3" {
    bucket         = "sample-cicd-tfstate"
    key            = "terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "sample-cicd-tflock"
    encrypt        = true
  }

  required_version = ">= 1.0"
  # ... 既存の required_providers ...
}
```

> **注意**: `backend` ブロック内では変数や locals を使用できない（Terraform の制約）。
> バケット名、リージョン、テーブル名はハードコードする必要がある。

#### variables.tf（変更）

```hcl
# --- v3: HTTPS (廃止) ---
# v8 で削除:
# variable "enable_https" { ... }
# variable "domain_name" { ... }    ← v7 の custom_domain_name に統一済みのため削除

# --- v7 → v8: Custom Domain (変更なし、v7 で定義済み) ---
# variable "enable_custom_domain" { ... }   # そのまま継続
# variable "custom_domain_name" { ... }     # そのまま継続
# variable "hosted_zone_id" { ... }         # そのまま継続
```

削除する変数:

| 変数名 | バージョン | 削除理由 |
|--------|----------|---------|
| `enable_https` | v3 | `enable_custom_domain` に統一 |
| `domain_name` | v3 | `custom_domain_name` に統一（v7 で追加済み） |

継続する変数（変更なし）:

| 変数名 | デフォルト | 説明 |
|--------|----------|------|
| `enable_custom_domain` | `false` | カスタムドメインの有効化フラグ |
| `custom_domain_name` | `""` | カスタムドメイン名 |
| `hosted_zone_id` | `""` | Route 53 Hosted Zone ID |

#### outputs.tf（v8 追加）

```hcl
# --- v8: Custom Domain ---
output "custom_domain_url" {
  description = "Custom domain URL (empty if custom domain is disabled)"
  value       = var.enable_custom_domain ? "https://${var.custom_domain_name}" : ""
}

output "app_url" {
  description = "Application URL (custom domain or CloudFront domain)"
  value       = var.enable_custom_domain ? "https://${var.custom_domain_name}" : "https://${aws_cloudfront_distribution.webui.domain_name}"
}
```

#### dev.tfvars（v8 変更）

```hcl
# v7 → v8: HTTPS + Custom Domain (有効化)
# enable_https を削除（v3 の変数は廃止）
enable_custom_domain = true
custom_domain_name   = "dev.sample-cicd.click"
hosted_zone_id       = "Z0XXXXXXXXXXXXXXXXXX"
```

#### prod.tfvars（v8 変更）

```hcl
# v7 → v8: HTTPS + Custom Domain (有効化)
# enable_https を削除（v3 の変数は廃止）
enable_custom_domain = true
custom_domain_name   = "sample-cicd.click"
hosted_zone_id       = "Z0XXXXXXXXXXXXXXXXXX"

# v8: CORS (カスタムドメイン)
cors_allowed_origins = ["https://sample-cicd.click"]
```

## 3. リソース依存関係

```
# Custom Domain
data.aws_route53_zone.main
  └── aws_acm_certificate.cloudfront (us-east-1, ワイルドカード)
       └── aws_route53_record.cert_validation (DNS 検証)
            └── aws_acm_certificate_validation.cloudfront
                 └── aws_cloudfront_distribution.webui (viewer_certificate)
  └── aws_route53_record.webui (ALIAS → CloudFront)

# Bootstrap (別ディレクトリ)
aws_s3_bucket.tfstate
  └── aws_s3_bucket_versioning.tfstate
  └── aws_s3_bucket_public_access_block.tfstate
  └── aws_s3_bucket_server_side_encryption_configuration.tfstate
aws_dynamodb_table.tflock
```

## 4. デプロイ手順

v8 のデプロイは以下の順序で行う（bootstrap → state 移行 → custom domain の順）:

```
Step 1: Bootstrap (Remote State 基盤)
  cd infra/bootstrap
  terraform init
  terraform apply

Step 2: State マイグレーション
  cd infra
  # main.tf に backend "s3" ブロックを追加後:
  terraform init -migrate-state
  # → "Copy existing state?" に yes

Step 3: カスタムドメイン適用
  terraform plan -var-file=dev.tfvars
  terraform apply -var-file=dev.tfvars
  # → ACM 証明書の DNS 検証に数分かかる
```

## 5. コスト影響

| リソース | 月額コスト |
|---------|----------|
| ACM 証明書 | $0（パブリック証明書は無料） |
| Route 53 Hosted Zone | $0（既存、追加コストなし） |
| Route 53 クエリ | $0.40/100 万クエリ（学習用途ではほぼ $0） |
| S3 (tfstate) | $0（数 KB のファイル） |
| DynamoDB (tflock) | $0（PAY_PER_REQUEST、ほぼ使用なし） |
| **v8 追加合計** | **~$0/月** |
