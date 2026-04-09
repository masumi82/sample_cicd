# --- v8: Custom Domain (HTTPS + Route 53) ---
#
# enable_custom_domain = true の場合に有効化。
# CloudFront に ACM 証明書とカスタムドメインを設定する。

# Existing Hosted Zone (auto-created when domain was purchased via Route 53)
data "aws_route53_zone" "main" {
  count   = var.enable_custom_domain ? 1 : 0
  zone_id = var.hosted_zone_id
}

# ACM certificate (us-east-1, required for CloudFront)
resource "aws_acm_certificate" "cloudfront" {
  count    = var.enable_custom_domain ? 1 : 0
  provider = aws.us_east_1

  domain_name               = "*.${data.aws_route53_zone.main[0].name}"
  subject_alternative_names = [data.aws_route53_zone.main[0].name]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.prefix}-cloudfront-cert"
  }
}

# ACM DNS validation CNAME records
resource "aws_route53_record" "cert_validation" {
  for_each = var.enable_custom_domain ? {
    for dvo in aws_acm_certificate.cloudfront[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  zone_id         = data.aws_route53_zone.main[0].zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.record]
  allow_overwrite = true
}

# Wait for ACM certificate DNS validation to complete
resource "aws_acm_certificate_validation" "cloudfront" {
  count    = var.enable_custom_domain ? 1 : 0
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.cloudfront[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# Route 53 ALIAS record (CloudFront distribution)
resource "aws_route53_record" "webui" {
  count   = var.enable_custom_domain ? 1 : 0
  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = var.custom_domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.webui.domain_name
    zone_id                = aws_cloudfront_distribution.webui.hosted_zone_id
    evaluate_target_health = false
  }
}
