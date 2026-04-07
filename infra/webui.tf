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

  origin {
    domain_name              = aws_s3_bucket.webui.bucket_regional_domain_name
    origin_id                = "s3-webui"
    origin_access_control_id = aws_cloudfront_origin_access_control.webui.id
  }

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

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name        = "${local.prefix}-webui-cdn"
    Project     = var.project_name
    Environment = local.env
  }
}
