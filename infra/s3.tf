# S3 Bucket for file attachments
resource "aws_s3_bucket" "attachments" {
  bucket = "${local.prefix}-attachments"

  tags = {
    Name = "${local.prefix}-attachments"
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "attachments" {
  bucket = aws_s3_bucket.attachments.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket policy — allow CloudFront OAC to GetObject
resource "aws_s3_bucket_policy" "attachments" {
  bucket = aws_s3_bucket.attachments.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.attachments.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.attachments.arn
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.attachments]
}

# Server-side encryption (SSE-S3)
resource "aws_s3_bucket_server_side_encryption_configuration" "attachments" {
  bucket = aws_s3_bucket.attachments.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Versioning
resource "aws_s3_bucket_versioning" "attachments" {
  bucket = aws_s3_bucket.attachments.id

  versioning_configuration {
    status = var.s3_versioning_enabled ? "Enabled" : "Suspended"
  }
}

# --- v12: Lifecycle Rules ---

resource "aws_s3_bucket_lifecycle_configuration" "attachments" {
  bucket = aws_s3_bucket.attachments.id

  # Current versions → Standard-IA after N days
  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    filter {}

    transition {
      days          = var.s3_lifecycle_ia_days
      storage_class = "STANDARD_IA"
    }
  }

  # Noncurrent versions → Glacier → Delete
  rule {
    id     = "noncurrent-lifecycle"
    status = "Enabled"

    filter {}

    noncurrent_version_transition {
      noncurrent_days = var.s3_lifecycle_glacier_days
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.s3_lifecycle_expire_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.attachments]
}

# CORS configuration for presigned URL uploads
resource "aws_s3_bucket_cors_configuration" "attachments" {
  bucket = aws_s3_bucket.attachments.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT"]
    allowed_origins = var.cors_allowed_origins
    max_age_seconds = 3600
  }
}
