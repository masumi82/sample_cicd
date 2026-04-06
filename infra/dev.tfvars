# dev environment variables
project_name   = "sample-cicd"
aws_region     = "ap-northeast-1"
vpc_cidr       = "10.0.0.0/16"
app_port       = 8000
fargate_cpu    = 256
fargate_memory = 512
desired_count  = 1

# v2: RDS
db_instance_class    = "db.t3.micro"
db_allocated_storage = 20
db_name              = "sample_cicd"
db_port              = 5432

# v4: Lambda Layer
psycopg2_layer_arn = "arn:aws:lambda:ap-northeast-1:123456789012:layer:sample-cicd-psycopg2:2"

# v5: Multi-environment settings
db_multi_az             = false
log_retention_days      = 7
lambda_log_retention_days = 7
cloudfront_price_class  = "PriceClass_100"
cors_allowed_origins    = ["*"]        # dev: all origins allowed
s3_versioning_enabled   = false
