# prod environment variables
project_name   = "sample-cicd"
aws_region     = "ap-northeast-1"
vpc_cidr       = "10.0.0.0/16"
app_port       = 8000
fargate_cpu    = 512
fargate_memory = 1024
desired_count  = 2

# v2: RDS
db_instance_class    = "db.t3.small"
db_allocated_storage = 50
db_name              = "sample_cicd"
db_port              = 5432

# v3: Auto Scaling
ecs_min_count        = 2
ecs_max_count        = 6
ecs_cpu_target_value = 60.0

# v4: Lambda Layer
psycopg2_layer_arn = "arn:aws:lambda:ap-northeast-1:123456789012:layer:sample-cicd-psycopg2:1"

# v5: Multi-environment settings
db_multi_az               = true
log_retention_days        = 30
lambda_log_retention_days = 14
cloudfront_price_class    = "PriceClass_200"
cors_allowed_origins      = ["https://sample-cicd.click"]
s3_versioning_enabled     = true

# v6: Observability + Web UI
alarm_email                      = ""
alarm_alb_5xx_threshold          = 5
alarm_alb_latency_threshold      = 1.0
alarm_ecs_cpu_threshold          = 80
alarm_ecs_memory_threshold       = 80
alarm_rds_cpu_threshold          = 80
alarm_rds_free_storage_threshold = 5000000000 # 5 GB
alarm_rds_connections_threshold  = 100
alarm_lambda_errors_threshold    = 3
alarm_lambda_duration_threshold  = 5000 # 5 seconds

# v7: WAF + Auth
waf_rate_limit = 1000

# v8: Custom Domain + HTTPS
enable_custom_domain = true
custom_domain_name   = "sample-cicd.click"
hosted_zone_id       = "Z0XXXXXXXXXXXXXXXXXX"

# v9: CI/CD Automation
github_repo                = "masumi82/sample_cicd"
codedeploy_traffic_routing = "AllAtOnce"
enable_test_listener       = false
