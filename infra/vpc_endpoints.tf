# VPC Endpoint 用セキュリティグループ
resource "aws_security_group" "vpc_endpoint" {
  name        = "${local.prefix}-vpce-sg"
  description = "Security group for VPC Endpoints used by Lambda cleanup"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name    = "${local.prefix}-vpce-sg"
    Project = var.project_name
  }
}

resource "aws_security_group_rule" "vpce_from_lambda_cleanup" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.vpc_endpoint.id
  source_security_group_id = aws_security_group.lambda_cleanup.id
  description              = "HTTPS from Lambda cleanup"
}

# ECS タスクも private_dns_enabled により VPC エンドポイント経由で
# Secrets Manager / CloudWatch Logs にアクセスするため許可が必要
resource "aws_security_group_rule" "vpce_from_ecs_tasks" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.vpc_endpoint.id
  source_security_group_id = aws_security_group.ecs_tasks.id
  description              = "HTTPS from ECS tasks"
}

resource "aws_security_group_rule" "vpce_outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.vpc_endpoint.id
  description       = "Allow all outbound"
}

# Secrets Manager Interface Endpoint
# cleanup Lambda が VPC 内から Secrets Manager にアクセスするために必要
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true

  tags = {
    Name    = "${local.prefix}-secretsmanager-endpoint"
    Project = var.project_name
  }
}

# CloudWatch Logs Interface Endpoint
# VPC 内の cleanup Lambda がログを書き込むために必要
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true

  tags = {
    Name    = "${local.prefix}-logs-endpoint"
    Project = var.project_name
  }
}
