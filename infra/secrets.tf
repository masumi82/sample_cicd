# Random password for DB
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}|:,.<>?"
}

# Secrets Manager Secret
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${local.prefix}/db-credentials"
  description = "Database credentials for ${local.prefix}"

  tags = {
    Name = "${local.prefix}-db-credentials"
  }
}

# Secrets Manager Secret Version
resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "postgres"
    password = random_password.db_password.result
    host     = aws_db_instance.main.address
    port     = tostring(var.db_port)
    dbname   = var.db_name
  })
}
