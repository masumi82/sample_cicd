# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${local.prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = {
    Name = "${local.prefix}-alb"
  }
}

# Target Group — Blue (production traffic)
resource "aws_lb_target_group" "blue" {
  name        = "${local.prefix}-tg-blue"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = {
    Name        = "${local.prefix}-tg-blue"
    Project     = var.project_name
    Environment = local.env
  }
}

# Target Group — Green (new version for B/G deployment)
resource "aws_lb_target_group" "green" {
  name        = "${local.prefix}-tg-green"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = {
    Name        = "${local.prefix}-tg-green"
    Project     = var.project_name
    Environment = local.env
  }
}

# HTTP Listener
# CloudFront が HTTPS を終端するため、ALB は常に HTTP 転送
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }

  tags = {
    Name = "${local.prefix}-http-listener"
  }

  # CodeDeploy switches target groups during B/G deployment;
  # ignore to prevent Terraform from reverting the switch
  lifecycle {
    ignore_changes = [default_action]
  }
}
