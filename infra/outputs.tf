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
