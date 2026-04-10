variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "sample-cicd"
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-northeast-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "app_port" {
  description = "Port the application listens on"
  type        = number
  default     = 8000
}

variable "fargate_cpu" {
  description = "Fargate task CPU units"
  type        = number
  default     = 256
}

variable "fargate_memory" {
  description = "Fargate task memory in MB"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Number of ECS tasks to run"
  type        = number
  default     = 1
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "sample_cicd"
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 5432
}

# --- v3: Auto Scaling ---

variable "ecs_min_count" {
  description = "Minimum number of ECS tasks for Auto Scaling"
  type        = number
  default     = 1
}

variable "ecs_max_count" {
  description = "Maximum number of ECS tasks for Auto Scaling"
  type        = number
  default     = 3
}

variable "ecs_cpu_target_value" {
  description = "Target CPU utilization (%) for ECS Auto Scaling"
  type        = number
  default     = 70.0
}

# --- v3: HTTPS (removed in v8, replaced by enable_custom_domain) ---

# --- v4: Event-Driven Architecture ---

variable "lambda_log_retention_days" {
  description = "CloudWatch Logs retention in days for Lambda functions"
  type        = number
  default     = 7
}

variable "cleanup_schedule_expression" {
  description = "EventBridge Scheduler cron expression for task cleanup (UTC)"
  type        = string
  default     = "cron(0 15 * * ? *)" # 毎日 0:00 JST
}

variable "cleanup_retention_days" {
  description = "Days to retain completed tasks before cleanup Lambda deletes them"
  type        = number
  default     = 30
}

variable "psycopg2_layer_arn" {
  description = "ARN of the Lambda Layer containing psycopg2 for Python 3.12"
  type        = string
}

# --- v5: Storage + Multi-Environment ---

variable "db_multi_az" {
  description = "Enable Multi-AZ for RDS"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days for ECS app"
  type        = number
  default     = 14
}

variable "cloudfront_price_class" {
  description = "CloudFront price class (PriceClass_100, PriceClass_200, PriceClass_All)"
  type        = string
  default     = "PriceClass_100"
}

variable "cors_allowed_origins" {
  description = "Allowed origins for S3 CORS (presigned URL uploads)"
  type        = list(string)
  default     = ["*"]
}

variable "s3_versioning_enabled" {
  description = "Enable S3 bucket versioning"
  type        = bool
  default     = true
}

# --- v6: Observability + Web UI ---

variable "alarm_email" {
  description = "Email address for alarm notifications (empty = no subscription)"
  type        = string
  default     = ""
}

variable "alarm_alb_5xx_threshold" {
  description = "Threshold for ALB 5xx error count alarm"
  type        = number
  default     = 10
}

variable "alarm_alb_latency_threshold" {
  description = "Threshold for ALB response time alarm (seconds)"
  type        = number
  default     = 3.0
}

variable "alarm_ecs_cpu_threshold" {
  description = "Threshold for ECS CPU utilization alarm (%)"
  type        = number
  default     = 90
}

variable "alarm_ecs_memory_threshold" {
  description = "Threshold for ECS memory utilization alarm (%)"
  type        = number
  default     = 90
}

variable "alarm_rds_cpu_threshold" {
  description = "Threshold for RDS CPU utilization alarm (%)"
  type        = number
  default     = 90
}

variable "alarm_rds_free_storage_threshold" {
  description = "Threshold for RDS free storage alarm (bytes, default 2GB)"
  type        = number
  default     = 2000000000
}

variable "alarm_rds_connections_threshold" {
  description = "Threshold for RDS connection count alarm"
  type        = number
  default     = 50
}

variable "alarm_lambda_errors_threshold" {
  description = "Threshold for Lambda error count alarm"
  type        = number
  default     = 5
}

variable "alarm_lambda_duration_threshold" {
  description = "Threshold for Lambda duration alarm (milliseconds)"
  type        = number
  default     = 10000
}

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

variable "custom_domain_name" {
  description = "Custom domain name (e.g., app.example.com). Required when enable_custom_domain = true."
  type        = string
  default     = ""
}

variable "hosted_zone_id" {
  description = "Route53 Hosted Zone ID. Required when enable_custom_domain = true."
  type        = string
  default     = ""
}

# --- v9: CI/CD Automation ---

variable "github_repo" {
  description = "GitHub repository (owner/repo format) for OIDC trust policy"
  type        = string
}

variable "codedeploy_traffic_routing" {
  description = "CodeDeploy traffic routing type (AllAtOnce or Linear10PercentEvery1Minute)"
  type        = string
  default     = "AllAtOnce"
}

variable "enable_test_listener" {
  description = "Create test listener on port 8080 for B/G deployment testing"
  type        = bool
  default     = false
}

# --- v10: API Gateway + ElastiCache ---

variable "redis_node_type" {
  description = "ElastiCache Redis node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_port" {
  description = "ElastiCache Redis port"
  type        = number
  default     = 6379
}

variable "apigw_cache_ttl" {
  description = "API Gateway cache TTL in seconds"
  type        = number
  default     = 300
}

variable "apigw_throttle_rate_limit" {
  description = "API Gateway steady-state request rate limit (requests/sec)"
  type        = number
  default     = 50
}

variable "apigw_throttle_burst_limit" {
  description = "API Gateway burst request limit"
  type        = number
  default     = 100
}

variable "apigw_quota_limit" {
  description = "API Gateway usage plan quota (requests per period)"
  type        = number
  default     = 10000
}

variable "apigw_quota_period" {
  description = "API Gateway usage plan quota period (DAY, WEEK, MONTH)"
  type        = string
  default     = "DAY"
}

variable "app_cache_ttl_list" {
  description = "Application-level Redis cache TTL for task list (seconds)"
  type        = number
  default     = 300
}

variable "app_cache_ttl_detail" {
  description = "Application-level Redis cache TTL for individual task (seconds)"
  type        = number
  default     = 600
}

variable "alarm_apigw_5xx_threshold" {
  description = "Threshold for API Gateway 5xx error count alarm"
  type        = number
  default     = 10
}

variable "alarm_redis_cpu_threshold" {
  description = "Threshold for ElastiCache Redis CPU utilization alarm (%)"
  type        = number
  default     = 90
}

variable "alarm_apigw_latency_threshold" {
  description = "Threshold for API Gateway integration latency alarm (ms)"
  type        = number
  default     = 5000
}

# --- v12: Disaster Recovery + Data Protection ---

variable "db_backup_retention_period" {
  description = "RDS backup retention period in days"
  type        = number
  default     = 7
}

variable "db_deletion_protection" {
  description = "Enable RDS deletion protection"
  type        = bool
  default     = false
}

variable "enable_read_replica" {
  description = "Create RDS Read Replica for read scaling"
  type        = bool
  default     = false
}

variable "enable_s3_replication" {
  description = "Enable S3 Cross-Region Replication for DR"
  type        = bool
  default     = false
}

variable "dr_region" {
  description = "DR region for S3 Cross-Region Replication"
  type        = string
  default     = "us-west-2"
}

variable "backup_retention_daily" {
  description = "AWS Backup daily backup retention in days"
  type        = number
  default     = 7
}

variable "backup_retention_weekly" {
  description = "AWS Backup weekly backup retention in days"
  type        = number
  default     = 30
}

variable "s3_lifecycle_ia_days" {
  description = "Days before transitioning current S3 objects to Standard-IA"
  type        = number
  default     = 90
}

variable "s3_lifecycle_glacier_days" {
  description = "Days before transitioning noncurrent S3 versions to Glacier"
  type        = number
  default     = 30
}

variable "s3_lifecycle_expire_days" {
  description = "Days before deleting noncurrent S3 versions"
  type        = number
  default     = 90
}

variable "alarm_replica_lag_threshold" {
  description = "Threshold for RDS ReplicaLag alarm (seconds)"
  type        = number
  default     = 30
}

# --- v13: Security Monitoring + Compliance ---

variable "enable_guardduty" {
  description = "Enable GuardDuty threat detection"
  type        = bool
  default     = true
}

variable "enable_securityhub" {
  description = "Enable Security Hub with CIS and FSBP standards"
  type        = bool
  default     = true
}

variable "cloudtrail_log_retention_days" {
  description = "Days to retain CloudTrail logs in S3"
  type        = number
  default     = 90
}

variable "cloudtrail_cw_log_retention_days" {
  description = "CloudWatch Logs retention for CloudTrail"
  type        = number
  default     = 14
}
