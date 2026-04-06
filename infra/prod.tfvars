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
ecs_min_count      = 2
ecs_max_count      = 6
ecs_cpu_target_value = 60.0

# v4: Lambda Layer
psycopg2_layer_arn = "arn:aws:lambda:ap-northeast-1:123456789012:layer:sample-cicd-psycopg2:1"

# v5: Multi-environment settings
db_multi_az             = true
log_retention_days      = 30
lambda_log_retention_days = 14
cloudfront_price_class  = "PriceClass_200"
cors_allowed_origins    = ["https://*.example.com"]  # TODO: replace with actual domain
s3_versioning_enabled   = true
