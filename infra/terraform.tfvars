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
