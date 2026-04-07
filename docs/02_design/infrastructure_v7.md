# Terraform リソース設計書 (v7)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-07 |
| バージョン | 7.0 |
| 前バージョン | [infrastructure_v6.md](infrastructure_v6.md) (v6.0) |

## 変更概要

v6 の 91 アクティブリソースに以下を追加する:

- **新規ファイル**: `cognito.tf`, `waf.tf`
- **変更ファイル**: `variables.tf`（v7 変数追加）、`outputs.tf`（Cognito / WAF 出力追加）、`dev.tfvars`（v7 パラメータ追加）、`prod.tfvars`（v7 パラメータ追加）、`ecs.tf`（Cognito 環境変数追加）、`webui.tf`（WAF 関連付け追加）、`main.tf`（us-east-1 プロバイダ追加）
- **追加リソース数**: 4 リソース（+ オプション 3 リソース）
- **主要機能**: Cognito ユーザー認証、WAF Web 攻撃防御

デプロイ後のアクティブリソース: 91 + 4 = **95 リソース**（dev 環境、HTTPS オプション除く）

## 1. Terraform リソース一覧

### v6 から継続（91 リソース）

（v6 の一覧と同一。詳細は [infrastructure_v6.md](infrastructure_v6.md) を参照）

> **重要変更**: ECS タスク定義に `COGNITO_USER_POOL_ID`, `COGNITO_APP_CLIENT_ID` 環境変数が追加される。
> CloudFront ディストリビューション（webui）に WAF WebACL が関連付けられる。

### v7 新規（4 リソース）

#### cognito.tf（2 リソース）

| # | リソースタイプ | リソース名 | 用途 |
|---|--------------|-----------|------|
| 92 | `aws_cognito_user_pool` | `main` | ユーザー認証基盤 |
| 93 | `aws_cognito_user_pool_client` | `spa` | SPA 向け App Client（シークレットなし） |

#### waf.tf（2 リソース）

| # | リソースタイプ | リソース名 | 用途 |
|---|--------------|-----------|------|
| 94 | `aws_wafv2_web_acl` | `cloudfront` | CloudFront 用 WebACL（us-east-1） |
| 95 | `aws_s3_bucket_policy` | `webui` | WebACL → CloudFront 関連付け（webui.tf で設定） |

> **注**: WAF WebACL の CloudFront への関連付けは `aws_cloudfront_distribution` の `web_acl_id` 属性で行う。
> 別途 `aws_wafv2_web_acl_association` は不要（CloudFront の場合）。

#### オプション: HTTPS + カスタムドメイン（3 リソース、`enable_custom_domain = true` 時のみ）

| # | リソースタイプ | リソース名 | 用途 |
|---|--------------|-----------|------|
| 96 | `aws_acm_certificate` | `webui` | SSL/TLS 証明書（us-east-1） |
| 97 | `aws_route53_record` | `cert_validation` | ACM DNS 検証レコード |
| 98 | `aws_route53_record` | `webui` | CloudFront への ALIAS レコード |

## 2. ファイル構成

### 2.1 新規ファイル

#### cognito.tf

```hcl
# --- v7: Cognito User Pool ---

resource "aws_cognito_user_pool" "main" {
  name = "${local.prefix}-users"

  # ユーザー名として email を使用
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  # パスワードポリシー
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = true
  }

  # email 確認
  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject        = "${local.prefix} - Verify your email"
    email_message        = "Your verification code is {####}"
  }

  # アカウント回復
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  tags = {
    Name        = "${local.prefix}-users"
    Project     = var.project_name
    Environment = local.env
  }
}

resource "aws_cognito_user_pool_client" "spa" {
  name         = "${local.prefix}-spa"
  user_pool_id = aws_cognito_user_pool.main.id

  # SPA 向け: クライアントシークレットなし
  generate_secret = false

  # 認証フロー
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",       # SRP (Secure Remote Password) プロトコル
    "ALLOW_REFRESH_TOKEN_AUTH",  # Refresh Token による再認証
  ]

  # トークン有効期間
  id_token_validity      = 1   # 1 時間
  access_token_validity  = 1   # 1 時間
  refresh_token_validity = 30  # 30 日

  token_validity_units {
    id_token      = "hours"
    access_token  = "hours"
    refresh_token = "days"
  }

  # サポートする認証フロー
  supported_identity_providers = ["COGNITO"]
}
```

#### waf.tf

```hcl
# --- v7: WAF v2 (CloudFront 用、us-east-1 に作成) ---

resource "aws_wafv2_web_acl" "cloudfront" {
  provider = aws.us_east_1

  name  = "${local.prefix}-webui-waf"
  scope = "CLOUDFRONT"  # CloudFront 用は CLOUDFRONT スコープ

  default_action {
    allow {}
  }

  # Rule 1: AWS マネージドルール — 一般的な攻撃防御
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.prefix}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: AWS マネージドルール — 既知の悪意ある入力防御
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.prefix}-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # Rule 3: IP レートリミット
  rule {
    name     = "RateLimitPerIP"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.prefix}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.prefix}-webui-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name        = "${local.prefix}-webui-waf"
    Project     = var.project_name
    Environment = local.env
  }
}
```

### 2.2 変更ファイル

#### main.tf（追加）

```hcl
# WAF (CloudFront 用) は us-east-1 に作成する必要がある
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
```

#### ecs.tf（環境変数追加）

```hcl
# app コンテナの environment に追加:
{
  name  = "COGNITO_USER_POOL_ID"
  value = aws_cognito_user_pool.main.id
},
{
  name  = "COGNITO_APP_CLIENT_ID"
  value = aws_cognito_user_pool_client.spa.id
}
```

#### webui.tf（WAF 関連付け追加）

```hcl
# aws_cloudfront_distribution.webui に追加:
resource "aws_cloudfront_distribution" "webui" {
  # ... 既存設定 ...

  web_acl_id = aws_wafv2_web_acl.cloudfront.arn  # v7: WAF 関連付け

  # ... 既存設定 ...
}
```

#### variables.tf（v7 追加）

```hcl
# --- v7: WAF ---
variable "waf_rate_limit" {
  description = "WAF rate limit per IP (requests per 5 minutes)"
  type        = number
  default     = 2000
}

# --- v7: HTTPS + Custom Domain (optional) ---
variable "enable_custom_domain" {
  description = "Enable custom domain with ACM + Route53"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "Custom domain name (e.g., app.example.com)"
  type        = string
  default     = ""
}

variable "hosted_zone_id" {
  description = "Route53 Hosted Zone ID"
  type        = string
  default     = ""
}
```

#### outputs.tf（v7 追加）

```hcl
# --- v7: Cognito ---
output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.main.id
}

output "cognito_app_client_id" {
  value = aws_cognito_user_pool_client.spa.id
}

# --- v7: WAF ---
output "waf_web_acl_arn" {
  value = aws_wafv2_web_acl.cloudfront.arn
}
```

#### dev.tfvars（v7 追加）

```hcl
# v7: WAF
waf_rate_limit = 2000  # dev: 緩め

# v7: HTTPS (optional, default disabled)
enable_custom_domain = false
domain_name          = ""
hosted_zone_id       = ""
```

#### prod.tfvars（v7 追加）

```hcl
# v7: WAF
waf_rate_limit = 1000  # prod: 厳しめ

# v7: HTTPS (optional)
enable_custom_domain = false
domain_name          = ""
hosted_zone_id       = ""
```

## 3. リソース依存関係

```
aws_cognito_user_pool.main
  └── aws_cognito_user_pool_client.spa
  └── aws_ecs_task_definition.app (環境変数で参照)

aws_wafv2_web_acl.cloudfront (us-east-1)
  └── aws_cloudfront_distribution.webui (web_acl_id で参照)
```

## 4. コスト影響

| リソース | 月額コスト |
|---------|----------|
| Cognito User Pool | $0（50,000 MAU 無料枠内） |
| WAF WebACL | $5.00 |
| WAF ルール × 3 | $3.00（$1.00/ルール） |
| WAF リクエスト | $0（学習用途は 100 万件未満） |
| **v7 追加合計** | **$8.00/月** |
