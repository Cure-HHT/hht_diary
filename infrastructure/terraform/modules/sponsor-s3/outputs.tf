# Sponsor S3 Module Outputs

output "artifacts_bucket_id" {
  description = "ID of the artifacts bucket"
  value       = aws_s3_bucket.artifacts.id
}

output "artifacts_bucket_arn" {
  description = "ARN of the artifacts bucket"
  value       = aws_s3_bucket.artifacts.arn
}

output "artifacts_bucket_domain_name" {
  description = "Domain name of the artifacts bucket"
  value       = aws_s3_bucket.artifacts.bucket_domain_name
}

output "artifacts_locked_bucket_id" {
  description = "ID of the artifacts bucket with object lock (if enabled)"
  value       = var.enable_object_lock ? aws_s3_bucket.artifacts_locked[0].id : null
}

output "artifacts_locked_bucket_arn" {
  description = "ARN of the artifacts bucket with object lock (if enabled)"
  value       = var.enable_object_lock ? aws_s3_bucket.artifacts_locked[0].arn : null
}

output "backups_bucket_id" {
  description = "ID of the backups bucket"
  value       = aws_s3_bucket.backups.id
}

output "backups_bucket_arn" {
  description = "ARN of the backups bucket"
  value       = aws_s3_bucket.backups.arn
}

output "logs_bucket_id" {
  description = "ID of the logs bucket"
  value       = aws_s3_bucket.logs.id
}

output "logs_bucket_arn" {
  description = "ARN of the logs bucket"
  value       = aws_s3_bucket.logs.arn
}

output "cicd_policy_arn" {
  description = "ARN of the CI/CD access policy"
  value       = aws_iam_policy.cicd_artifacts_access.arn
}

output "cicd_user_name" {
  description = "Name of the CI/CD IAM user (if created)"
  value       = var.create_cicd_user ? aws_iam_user.cicd[0].name : null
}

output "cicd_user_arn" {
  description = "ARN of the CI/CD IAM user (if created)"
  value       = var.create_cicd_user ? aws_iam_user.cicd[0].arn : null
}

# Test Buckets Outputs
output "staging_bucket_id" {
  description = "ID of the staging test bucket (if created)"
  value       = var.create_test_buckets ? aws_s3_bucket.artifacts_staging[0].id : null
}

output "staging_bucket_arn" {
  description = "ARN of the staging test bucket (if created)"
  value       = var.create_test_buckets ? aws_s3_bucket.artifacts_staging[0].arn : null
}

output "dev_bucket_id" {
  description = "ID of the development test bucket (if created)"
  value       = var.create_test_buckets ? aws_s3_bucket.artifacts_dev[0].id : null
}

output "dev_bucket_arn" {
  description = "ARN of the development test bucket (if created)"
  value       = var.create_test_buckets ? aws_s3_bucket.artifacts_dev[0].arn : null
}
