# --- v6: Web UI S3 + CloudFront ---

# S3 bucket for Web UI static assets
resource "aws_s3_bucket" "webui" {
  bucket = "${local.prefix}-webui"

  tags = {
    Name        = "${local.prefix}-webui"
    Project     = var.project_name
    Environment = local.env
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "webui" {
  bucket                  = aws_s3_bucket.webui.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket policy: allow CloudFront OAC access only
resource "aws_s3_bucket_policy" "webui" {
  bucket = aws_s3_bucket.webui.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.webui.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.webui.arn
          }
        }
      }
    ]
  })
}

# CloudFront OAC for Web UI
resource "aws_cloudfront_origin_access_control" "webui" {
  name                              = "${local.prefix}-webui-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront distribution for Web UI
resource "aws_cloudfront_distribution" "webui" {
  enabled             = true
  default_root_object = "index.html"
  price_class         = var.cloudfront_price_class
  comment             = "${local.prefix} webui CDN"
  web_acl_id          = aws_wafv2_web_acl.cloudfront.arn

  # v8: Custom domain
  aliases = var.enable_custom_domain ? [var.custom_domain_name] : []

  # Origin 1: S3 (static assets)
  origin {
    domain_name              = aws_s3_bucket.webui.bucket_regional_domain_name
    origin_id                = "s3-webui"
    origin_access_control_id = aws_cloudfront_origin_access_control.webui.id
  }

  # Origin 2: API Gateway (API proxy) — v10: changed from ALB to API Gateway
  origin {
    domain_name = "${aws_api_gateway_rest_api.main.id}.execute-api.${var.aws_region}.amazonaws.com"
    origin_id   = "apigw-api"
    origin_path = "/${aws_api_gateway_stage.main.stage_name}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    custom_header {
      name  = "x-api-key"
      value = aws_api_gateway_api_key.main.value
    }
  }

  # API behavior: /tasks* → API Gateway (no CloudFront caching, API GW handles cache)
  ordered_cache_behavior {
    path_pattern     = "/tasks*"
    target_origin_id = "apigw-api"

    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    viewer_protocol_policy = "https-only"

    # AWS managed: CachingDisabled
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    # AWS managed: AllViewerExceptHostHeader (forward query strings, headers except Host)
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
  }

  # Default behavior: S3 (SPA static assets)
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-webui"
    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id
  }

  # SPA routing: fallback 403/404 to index.html
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # v8: Switch viewer_certificate based on custom domain
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

  tags = {
    Name        = "${local.prefix}-webui-cdn"
    Project     = var.project_name
    Environment = local.env
  }
}
