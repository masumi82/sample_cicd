output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = aws_lb.main.dns_name
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.app.name
}

output "rds_endpoint" {
  description = "Endpoint of the RDS instance"
  value       = aws_db_instance.main.endpoint
}

output "secrets_manager_arn" {
  description = "ARN of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "sqs_queue_url" {
  description = "URL of the SQS task events queue"
  value       = aws_sqs_queue.task_events.url
}

output "eventbridge_bus_name" {
  description = "Name of the EventBridge custom event bus"
  value       = aws_cloudwatch_event_bus.main.name
}

output "lambda_task_created_arn" {
  description = "ARN of the task_created_handler Lambda function"
  value       = aws_lambda_function.task_created_handler.arn
}

output "lambda_task_completed_arn" {
  description = "ARN of the task_completed_handler Lambda function"
  value       = aws_lambda_function.task_completed_handler.arn
}

output "lambda_task_cleanup_arn" {
  description = "ARN of the task_cleanup_handler Lambda function"
  value       = aws_lambda_function.task_cleanup_handler.arn
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for attachments"
  value       = aws_s3_bucket.attachments.bucket
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.attachments.domain_name
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.attachments.id
}

# --- v6: Observability + Web UI outputs ---

output "dashboard_url" {
  description = "URL of the CloudWatch Dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "sns_topic_arn" {
  description = "ARN of the alarm notification SNS topic"
  value       = aws_sns_topic.alarm_notifications.arn
}

output "webui_bucket_name" {
  description = "Name of the Web UI S3 bucket"
  value       = aws_s3_bucket.webui.bucket
}

output "webui_cloudfront_domain_name" {
  description = "Domain name of the Web UI CloudFront distribution"
  value       = aws_cloudfront_distribution.webui.domain_name
}

output "webui_cloudfront_distribution_id" {
  description = "ID of the Web UI CloudFront distribution"
  value       = aws_cloudfront_distribution.webui.id
}

# --- v7: Cognito + WAF outputs ---

output "cognito_user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_app_client_id" {
  description = "ID of the Cognito App Client"
  value       = aws_cognito_user_pool_client.spa.id
}

output "waf_web_acl_arn" {
  description = "ARN of the WAF WebACL"
  value       = aws_wafv2_web_acl.cloudfront.arn
}
