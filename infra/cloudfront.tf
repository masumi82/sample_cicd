# Origin Access Control (OAC) for CloudFront → S3
resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "${local.prefix}-s3-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# AWS managed cache policy reference
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

# CloudFront distribution for serving attachments from S3
resource "aws_cloudfront_distribution" "attachments" {
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
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "${local.prefix}-cdn"
  }
}
