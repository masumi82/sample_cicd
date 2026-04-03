# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = var.project_name
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# RDS PostgreSQL
resource "aws_db_instance" "main" {
  identifier     = var.project_name
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

  multi_az            = true
  publicly_accessible = false

  skip_final_snapshot    = true
  backup_retention_period = 0
  deletion_protection    = false

  tags = {
    Name = "${var.project_name}-rds"
  }
}
