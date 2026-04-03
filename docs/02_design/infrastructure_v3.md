# Terraform リソース設計書 (v3)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-03 |
| バージョン | 3.0 |
| 前バージョン | [infrastructure_v2.md](infrastructure_v2.md) (v2.0) |

## 変更概要

v2 の 33 リソースに以下を追加・変更する:

- **追加（デプロイあり）**: Auto Scaling 関連 2 リソース（autoscaling.tf 新規）
- **追加（コードのみ）**: HTTPS 関連 6 リソース（https.tf 新規、`enable_https = false` で無効）
- **変更**: RDS Multi-AZ 有効化（rds.tf 変更）
- **変更**: variables.tf に Auto Scaling / HTTPS 変数追加

デプロイ後のアクティブリソース: 33 + 2 = **35 リソース**
Terraform で管理するリソース定義総数: 33 + 2 + 6 = **41 リソース定義**

## 1. Terraform リソース一覧

### v1 & v2 から継続（33 リソース）

（v2 の一覧と同一。詳細は [infrastructure_v2.md](infrastructure_v2.md) を参照）

| # | リソースタイプ | リソース名 | v3 変更 |
|---|--------------|-----------|---------|
| 1〜20 | v1 リソース | — | なし（ecs.tf は後述の変更あり） |
| 21〜33 | v2 リソース | — | rds.tf のみ変更 |

### v3 新規 / 変更（8 リソース定義）

| # | リソースタイプ | リソース名 | 用途 | ファイル | デプロイ |
|---|--------------|-----------|------|----------|:-------:|
| 34 | `aws_appautoscaling_target` | `ecs_service` | ECS サービスをスケーラブルターゲットとして登録 | autoscaling.tf | ✅ |
| 35 | `aws_appautoscaling_policy` | `ecs_cpu` | CPU ベースのターゲット追跡スケーリングポリシー | autoscaling.tf | ✅ |
| 36 | `aws_acm_certificate` | `app` | ACM パブリック証明書（DNS 検証） | https.tf | コードのみ |
| 37 | `aws_route53_zone` | `app` | Route53 ホストゾーン | https.tf | コードのみ |
| 38 | `aws_route53_record` | `acm_validation` | ACM DNS 検証用 CNAME レコード | https.tf | コードのみ |
| 39 | `aws_acm_certificate_validation` | `app` | ACM 証明書の DNS 検証完了待機 | https.tf | コードのみ |
| 40 | `aws_route53_record` | `app` | ALB へのエイリアス A レコード | https.tf | コードのみ |
| 41 | `aws_lb_listener` | `https` | ALB HTTPS リスナー（ポート 443） | https.tf | コードのみ |

> **コードのみリソース:** `count = var.enable_https ? 1 : 0` で制御。
> `enable_https = false`（デフォルト）の場合、Terraform は定義を認識するが、リソースは作成しない。

## 2. ファイル構成

```
infra/
├── main.tf              # Provider, VPC, サブネット [変更なし]
├── alb.tf               # ALB, ターゲットグループ, HTTP リスナー [変更: HTTPリスナーの条件分岐追加]
├── ecr.tf               # ECR リポジトリ [変更なし]
├── ecs.tf               # ECS クラスター, タスク定義, サービス [変更なし]
├── iam.tf               # IAM ロール, ポリシー [変更なし]
├── security_groups.tf   # セキュリティグループ [変更: ALB SG に 443 ルール条件追加]
├── logs.tf              # CloudWatch ロググループ [変更なし]
├── rds.tf               # RDS PostgreSQL [変更: multi_az = true]
├── secrets.tf           # Secrets Manager [変更なし]
├── autoscaling.tf       # Application Auto Scaling [新規]
├── https.tf             # ACM + Route53 + HTTPS リスナー [新規・コードのみ]
├── variables.tf         # 入力変数 [変更: Auto Scaling / HTTPS 変数追加]
├── outputs.tf           # 出力値 [変更なし]
└── terraform.tfvars     # 変数値 [変更: Auto Scaling デフォルト値]
```

## 3. 新規リソース詳細設計

### 3.1 autoscaling.tf（新規）

```
aws_appautoscaling_target "ecs_service":
  max_capacity       = var.ecs_max_count      # 3
  min_capacity       = var.ecs_min_count      # 1
  resource_id        = "service/<cluster_name>/<service_name>"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

aws_appautoscaling_policy "ecs_cpu":
  name               = "sample-cicd-cpu-target-tracking"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_service.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service.service_namespace

  target_tracking_scaling_policy_configuration:
    target_value       = var.ecs_cpu_target_value   # 70.0
    scale_in_cooldown  = 300  # スケールインは慎重に
    scale_out_cooldown = 60   # スケールアウトは素早く
    predefined_metric_specification:
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
```

> **設計判断 - `resource_id` の形式:**
> `"service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"` と Terraform の補間で動的に設定。
> ハードコードを避け、リソース名変更時の追従を容易にする。

> **設計判断 - Target Tracking Policy を選択した理由:**
> Step Scaling（段階的スケール）と比較して、Target Tracking はターゲット CPU 値を設定するだけで
> AWS が自動的にスケールイン・スケールアウトの閾値を計算するため、設定が簡潔。
> また CloudWatch Alarm も自動作成されるため、手動でアラームを定義する必要がない。

### 3.2 https.tf（新規・コードのみ）

すべてのリソースに `count = var.enable_https ? 1 : 0` を付与。

```
変数:
  enable_https  = false  (default)
  domain_name   = ""     (default, 取得時に設定)

aws_acm_certificate "app":
  count             = var.enable_https ? 1 : 0
  domain_name       = var.domain_name
  validation_method = "DNS"
  lifecycle:
    create_before_destroy = true

aws_route53_zone "app":
  count = var.enable_https ? 1 : 0
  name  = var.domain_name

aws_route53_record "acm_validation":
  count  = var.enable_https ? 1 : 0
  zone_id = aws_route53_zone.app[0].zone_id
  name    = (ACM が要求する CNAME 名)
  type    = "CNAME"
  ttl     = 60
  records = [(ACM が要求する CNAME 値)]

aws_acm_certificate_validation "app":
  count           = var.enable_https ? 1 : 0
  certificate_arn = aws_acm_certificate.app[0].arn
  validation_record_fqdns = [aws_route53_record.acm_validation[0].fqdn]

aws_route53_record "app" (A alias):
  count   = var.enable_https ? 1 : 0
  zone_id = aws_route53_zone.app[0].zone_id
  name    = var.domain_name
  type    = "A"
  alias:
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true

aws_lb_listener "https":
  count             = var.enable_https ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.app[0].certificate_arn
  default_action:
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
```

> **設計判断 - `ssl_policy`:**
> `ELBSecurityPolicy-TLS13-1-2-2021-06` は TLS 1.3 と TLS 1.2 をサポートする推奨ポリシー（2024年時点）。
> TLS 1.0/1.1 は無効化されており、セキュリティ要件（NFR-2）に適合。

## 4. 既存リソース変更詳細

### 4.1 RDS（rds.tf 変更）

**変更点:** `multi_az = false` → `multi_az = true`

```
Before:
  multi_az = false

After:
  multi_az = true
```

> **Multi-AZ の仕組み:**
> AWS が自動的に別の AZ（ap-northeast-1c）にスタンバイレプリカを作成し、同期レプリケーションを維持する。
> フェイルオーバー時は DNS 切り替えで自動的にスタンバイが Primary に昇格する（約 60〜120 秒）。
> アプリケーション側の設定変更は不要（DB 接続先のホスト名は変わらない）。

> **コストへの影響:** db.t3.micro の Multi-AZ は Single-AZ の約 2 倍（$15/月 → $30/月）。

### 4.2 ALB HTTP リスナー（alb.tf 変更）

**変更点:** HTTPS 有効時に HTTP リクエストを 301 リダイレクトするよう条件分岐を追加。

```hcl
# Before (v2):
resource "aws_lb_listener" "http" {
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# After (v3):
resource "aws_lb_listener" "http" {
  default_action {
    type = var.enable_https ? "redirect" : "forward"

    # HTTPS 有効時: 301 リダイレクト
    dynamic "redirect" {
      for_each = var.enable_https ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    # HTTPS 無効時: そのまま転送
    target_group_arn = var.enable_https ? null : aws_lb_target_group.app.arn
  }
}
```

### 4.3 ALB セキュリティグループ（security_groups.tf 変更）

**変更点:** `enable_https = true` 時に ALB SG へポート 443 の Inbound ルールを追加。

```hcl
# 追加するルール（動的ブロック）
dynamic "ingress" {
  for_each = var.enable_https ? [443] : []
  content {
    from_port   = ingress.value
    to_port     = ingress.value
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

## 5. 変数設計（variables.tf 変更）

### v1 & v2 変数（変更なし）

（[infrastructure_v2.md](infrastructure_v2.md) のセクション 5 を参照）

### v3 追加変数

| 変数名 | 型 | デフォルト値 | 説明 |
|--------|----|-------------|------|
| `ecs_min_count` | number | `1` | ECS タスクの最小数（Auto Scaling 下限） |
| `ecs_max_count` | number | `3` | ECS タスクの最大数（Auto Scaling 上限） |
| `ecs_cpu_target_value` | number | `70.0` | ターゲット CPU 使用率（%） |
| `enable_https` | bool | `false` | HTTPS 関連リソースの有効化フラグ |
| `domain_name` | string | `""` | カスタムドメイン名（enable_https=true 時に設定） |

> **設計判断 - `desired_count` と Auto Scaling の関係:**
> `variables.tf` の既存変数 `desired_count = 1` は ECS サービスの初期タスク数として使用される。
> Auto Scaling が有効になると、`desired_count` は Auto Scaling の管理下に入り、
> `ecs_min_count` 〜 `ecs_max_count` の範囲で動的に変化する。
> `desired_count` は Auto Scaling の `min_capacity` と合わせて `1` に設定する。

## 6. 出力値設計（outputs.tf 変更なし）

v2 の出力値（`alb_dns_name`, `ecr_repository_url`, `ecs_cluster_name`, `ecs_service_name`, `rds_endpoint`, `secrets_manager_arn`）から変更なし。

HTTPS 有効化後に Route53 のネームサーバーを確認する必要があるが、
`enable_https = false` がデフォルトのため、現時点では outputs.tf への追加なし。

## 7. リソース依存関係（v3 追加分）

```
aws_ecs_cluster.main + aws_ecs_service.app
    └──▶ aws_appautoscaling_target.ecs_service
              └──▶ aws_appautoscaling_policy.ecs_cpu
                        └──▶ (CloudWatch Alarm が自動生成される)

var.enable_https = true の場合のみ:
aws_lb.main
    └──▶ aws_lb_listener.https (aws_acm_certificate_validation が完了後)
aws_route53_zone.app
    └──▶ aws_route53_record.acm_validation
              └──▶ aws_acm_certificate_validation.app
                        └──▶ aws_lb_listener.https
    └──▶ aws_route53_record.app (A alias → aws_lb.main)
```

## 8. State 管理（変更なし）

| 項目 | 値 |
|------|------|
| Backend | local |
| State file | `infra/terraform.tfstate` |
