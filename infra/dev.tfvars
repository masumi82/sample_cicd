# dev environment variables
project_name   = "sample-cicd"
aws_region     = "ap-northeast-1"
vpc_cidr       = "10.0.0.0/16"
app_port       = 8000
fargate_cpu    = 512  # v6: increased for X-Ray sidecar (was 256)
fargate_memory = 1024 # v6: increased for X-Ray sidecar (was 512)
desired_count  = 1

# v2: RDS
db_instance_class    = "db.t3.micro"
db_allocated_storage = 20
db_name              = "sample_cicd"
db_port              = 5432

# v4: Lambda Layer
psycopg2_layer_arn = "arn:aws:lambda:ap-northeast-1:123456789012:layer:sample-cicd-psycopg2:2"

# v5: Multi-environment settings
db_multi_az               = false
log_retention_days        = 7
lambda_log_retention_days = 7
cloudfront_price_class    = "PriceClass_100"
cors_allowed_origins      = ["*"] # dev: all origins allowed
# s3_versioning_enabled — set in v12 section below

# v6: Observability + Web UI
alarm_email                      = ""
alarm_alb_5xx_threshold          = 10
alarm_alb_latency_threshold      = 3.0
alarm_ecs_cpu_threshold          = 90
alarm_ecs_memory_threshold       = 90
alarm_rds_cpu_threshold          = 90
alarm_rds_free_storage_threshold = 2000000000 # 2 GB
alarm_rds_connections_threshold  = 50
alarm_lambda_errors_threshold    = 5
alarm_lambda_duration_threshold  = 10000 # 10 seconds

# v7: WAF + Auth
waf_rate_limit = 2000

# v8: Custom Domain + HTTPS
enable_custom_domain = true
custom_domain_name   = "dev.sample-cicd.click"
hosted_zone_id       = "Z0XXXXXXXXXXXXXXXXXX"

# v9: CI/CD Automation
github_repo                = "masumi82/sample_cicd"
codedeploy_traffic_routing = "AllAtOnce"
enable_test_listener       = false

# v10: API Gateway + ElastiCache
redis_node_type            = "cache.t3.micro"
apigw_cache_ttl            = 300
apigw_throttle_rate_limit  = 50
apigw_throttle_burst_limit = 100
apigw_quota_limit          = 10000
apigw_quota_period         = "DAY"
app_cache_ttl_list         = 300
app_cache_ttl_detail       = 600

# v12: Disaster Recovery + Data Protection
db_backup_retention_period = 7
db_deletion_protection     = false
enable_read_replica        = false
enable_s3_replication      = false
s3_versioning_enabled      = true

# v13: Security Monitoring + Compliance
enable_guardduty              = true
enable_securityhub            = true
cloudtrail_log_retention_days = 90
