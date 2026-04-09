# --- v10: ElastiCache Redis ---

# Redis subnet group (same private subnets as RDS)
resource "aws_elasticache_subnet_group" "main" {
  name       = "${local.prefix}-redis"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name        = "${local.prefix}-redis-subnet-group"
    Project     = var.project_name
    Environment = local.env
  }
}

# Redis cluster (single node)
resource "aws_elasticache_cluster" "main" {
  cluster_id           = "${local.prefix}-redis"
  engine               = "redis"
  node_type            = var.redis_node_type
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  engine_version       = "7.0"
  port                 = var.redis_port
  security_group_ids   = [aws_security_group.redis.id]
  subnet_group_name    = aws_elasticache_subnet_group.main.name

  tags = {
    Name        = "${local.prefix}-redis"
    Project     = var.project_name
    Environment = local.env
  }
}
