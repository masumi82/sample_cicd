# Application Auto Scaling Target
# ECS サービスをスケーラブルターゲットとして登録する
resource "aws_appautoscaling_target" "ecs_service" {
  max_capacity       = var.ecs_max_count
  min_capacity       = var.ecs_min_count
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Target Tracking Scaling Policy (CPU-based)
# CPU 使用率が target_value に近づくようにタスク数を自動調整する
# CloudWatch Alarm はこのポリシーによって自動的に作成される
resource "aws_appautoscaling_policy" "ecs_cpu" {
  name               = "${var.project_name}-cpu-target-tracking"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_service.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.ecs_cpu_target_value
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
