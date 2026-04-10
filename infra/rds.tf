# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = local.prefix
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name = "${local.prefix}-db-subnet-group"
  }
}

# RDS PostgreSQL
resource "aws_db_instance" "main" {
  identifier     = local.prefix
  engine         = "postgres"
  engine_version = "15"
  instance_class = var.db_instance_class

  allocated_storage = var.db_allocated_storage
  storage_type      = "gp2"

  db_name  = var.db_name
  username = "postgres"
  password = random_password.db_password.result
  port     = var.db_port

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  multi_az            = var.db_multi_az
  publicly_accessible = false

  skip_final_snapshot       = false
  final_snapshot_identifier = "${local.prefix}-final-snapshot"
  backup_retention_period   = var.db_backup_retention_period
  deletion_protection       = var.db_deletion_protection

  tags = {
    Name   = "${local.prefix}-rds"
    Backup = "true"
  }
}

# --- v12: RDS Read Replica ---

resource "aws_db_instance" "read_replica" {
  count = var.enable_read_replica ? 1 : 0

  identifier          = "${local.prefix}-read-replica"
  replicate_source_db = aws_db_instance.main.identifier
  instance_class      = var.db_instance_class

  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible = false
  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name        = "${local.prefix}-rds-read-replica"
    Project     = var.project_name
    Environment = local.env
  }
}
