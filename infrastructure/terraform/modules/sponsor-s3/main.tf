# Sponsor S3 Archival Buckets Module
#
# Creates per-sponsor S3 buckets for FDA-compliant build artifact archival.
# Implements 7-year retention with lifecycle policies and versioning.
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00016: FDA compliance archival
#   REQ-o00017: Per-sponsor infrastructure isolation

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Artifacts Bucket (Build Outputs)
resource "aws_s3_bucket" "artifacts" {
  bucket = var.artifacts_bucket_name

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.sponsor_code} Build Artifacts"
      Purpose     = "FDA-compliant build artifact storage"
      Retention   = "7 years"
      Sponsor     = var.sponsor_name
      SponsorCode = var.sponsor_code
    }
  )
}

# Enable Versioning (FDA Requirement)
resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Public Access Block
resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle Policy (7-year retention, then archive to Glacier)
resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  # Current versions: Transition to Glacier after 90 days, retain for 7 years
  rule {
    id     = "archive-builds"
    status = "Enabled"

    filter {
      prefix = "builds/"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    transition {
      days          = 2555  # ~7 years
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = 2920  # 8 years (7 + 1 year buffer)
    }
  }

  # Old versions: Keep for 30 days then delete
  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }

  # Cleanup incomplete multipart uploads
  rule {
    id     = "cleanup-multipart"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Object Lock (Prevent Deletion - FDA Requirement)
# Note: Can only be enabled on bucket creation, requires separate bucket
resource "aws_s3_bucket" "artifacts_locked" {
  count = var.enable_object_lock ? 1 : 0

  bucket = "${var.artifacts_bucket_name}-locked"

  object_lock_enabled = true

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.sponsor_code} Build Artifacts (Locked)"
      Purpose     = "FDA-compliant build artifact storage with WORM"
      Retention   = "7 years"
      Sponsor     = var.sponsor_name
      SponsorCode = var.sponsor_code
      ObjectLock  = "Enabled"
    }
  )
}

resource "aws_s3_bucket_object_lock_configuration" "artifacts_locked" {
  count = var.enable_object_lock ? 1 : 0

  bucket = aws_s3_bucket.artifacts_locked[0].id

  rule {
    default_retention {
      mode = "GOVERNANCE"  # Allows deletion with special permissions
      days = 2920          # 8 years
    }
  }
}

# Backups Bucket (Database Backups)
resource "aws_s3_bucket" "backups" {
  bucket = var.backups_bucket_name

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.sponsor_code} Database Backups"
      Purpose     = "Portal database backups"
      Retention   = "90 days"
      Sponsor     = var.sponsor_name
      SponsorCode = var.sponsor_code
    }
  )
}

resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket = aws_s3_bucket.backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    id     = "expire-backups"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = 90
    }
  }

  rule {
    id     = "cleanup-multipart"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Logs Bucket (Application Logs)
resource "aws_s3_bucket" "logs" {
  bucket = var.logs_bucket_name

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.sponsor_code} Application Logs"
      Purpose     = "Portal application logs"
      Retention   = "30 days"
      Sponsor     = var.sponsor_name
      SponsorCode = var.sponsor_code
    }
  )
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-logs"
    status = "Enabled"

    transition {
      days          = 7
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = 30
    }
  }
}

# IAM Policy for CI/CD Access
resource "aws_iam_policy" "cicd_artifacts_access" {
  name        = "${var.sponsor_code}-cicd-artifacts-access"
  description = "Allow CI/CD to upload build artifacts for ${var.sponsor_name}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning"
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          var.enable_object_lock ? aws_s3_bucket.artifacts_locked[0].arn : aws_s3_bucket.artifacts.arn
        ]
      },
      {
        Sid    = "ReadWriteObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = [
          "${aws_s3_bucket.artifacts.arn}/*",
          var.enable_object_lock ? "${aws_s3_bucket.artifacts_locked[0].arn}/*" : "${aws_s3_bucket.artifacts.arn}/*"
        ]
      }
    ]
  })

  tags = merge(
    var.common_tags,
    {
      Sponsor     = var.sponsor_name
      SponsorCode = var.sponsor_code
    }
  )
}

# IAM User for CI/CD (Optional - use OIDC instead in production)
resource "aws_iam_user" "cicd" {
  count = var.create_cicd_user ? 1 : 0

  name = "${var.sponsor_code}-cicd-user"

  tags = merge(
    var.common_tags,
    {
      Sponsor     = var.sponsor_name
      SponsorCode = var.sponsor_code
      Purpose     = "CI/CD artifact upload"
    }
  )
}

resource "aws_iam_user_policy_attachment" "cicd_artifacts" {
  count = var.create_cicd_user ? 1 : 0

  user       = aws_iam_user.cicd[0].name
  policy_arn = aws_iam_policy.cicd_artifacts_access.arn
}
