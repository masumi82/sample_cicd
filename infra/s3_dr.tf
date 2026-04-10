# --- v12: S3 Cross-Region Replication for DR ---

# DR Bucket (us-west-2)
resource "aws_s3_bucket" "attachments_dr" {
  count    = var.enable_s3_replication ? 1 : 0
  provider = aws.dr
  bucket   = "${local.prefix}-attachments-dr"

  tags = {
    Name = "${local.prefix}-attachments-dr"
  }
}

resource "aws_s3_bucket_versioning" "attachments_dr" {
  count    = var.enable_s3_replication ? 1 : 0
  provider = aws.dr
  bucket   = aws_s3_bucket.attachments_dr[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "attachments_dr" {
  count    = var.enable_s3_replication ? 1 : 0
  provider = aws.dr
  bucket   = aws_s3_bucket.attachments_dr[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "attachments_dr" {
  count    = var.enable_s3_replication ? 1 : 0
  provider = aws.dr
  bucket   = aws_s3_bucket.attachments_dr[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Replication Configuration (source → DR)
resource "aws_s3_bucket_replication_configuration" "attachments" {
  count  = var.enable_s3_replication ? 1 : 0
  bucket = aws_s3_bucket.attachments.id
  role   = aws_iam_role.s3_replication[0].arn

  rule {
    id     = "replicate-all"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.attachments_dr[0].arn
      storage_class = "STANDARD"
    }
  }

  depends_on = [aws_s3_bucket_versioning.attachments]
}

# Replication IAM Role
resource "aws_iam_role" "s3_replication" {
  count = var.enable_s3_replication ? 1 : 0
  name  = "${local.prefix}-s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${local.prefix}-s3-replication-role"
  }
}

resource "aws_iam_policy" "s3_replication" {
  count = var.enable_s3_replication ? 1 : 0
  name  = "${local.prefix}-s3-replication-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.attachments.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = "${aws_s3_bucket.attachments.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = "${aws_s3_bucket.attachments_dr[0].arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_replication" {
  count      = var.enable_s3_replication ? 1 : 0
  role       = aws_iam_role.s3_replication[0].name
  policy_arn = aws_iam_policy.s3_replication[0].arn
}
