# HTTPS 関連リソース（コードのみ）
#
# このファイルのリソースはすべて enable_https = false（デフォルト）の場合は作成されない。
# カスタムドメインを取得した際に terraform.tfvars で以下を設定して terraform apply することで有効化できる:
#   enable_https = true
#   domain_name  = "your-domain.example.com"

# ACM パブリック証明書（DNS 検証方式）
resource "aws_acm_certificate" "app" {
  count             = var.enable_https ? 1 : 0
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.prefix}-cert"
  }
}

# Route53 ホストゾーン
resource "aws_route53_zone" "app" {
  count = var.enable_https ? 1 : 0
  name  = var.domain_name

  tags = {
    Name = "${local.prefix}-zone"
  }
}

# ACM DNS 検証用 CNAME レコード
# ACM が自動生成するドメイン検証オプションから CNAME レコードを作成する
resource "aws_route53_record" "acm_validation" {
  for_each = var.enable_https ? {
    for dvo in aws_acm_certificate.app[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  zone_id = aws_route53_zone.app[0].zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

# ACM 証明書の DNS 検証完了を待機する
resource "aws_acm_certificate_validation" "app" {
  count           = var.enable_https ? 1 : 0
  certificate_arn = aws_acm_certificate.app[0].arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation : record.fqdn]
}

# Route53 A レコード（ALB へのエイリアス）
resource "aws_route53_record" "app" {
  count   = var.enable_https ? 1 : 0
  zone_id = aws_route53_zone.app[0].zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# ALB HTTPS リスナー（ポート 443）
resource "aws_lb_listener" "https" {
  count             = var.enable_https ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.app[0].certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = {
    Name = "${local.prefix}-https-listener"
  }
}
