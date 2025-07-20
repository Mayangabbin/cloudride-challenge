
# CloudWatch Log Group for ECS Task Logs
resource "aws_cloudwatch_log_group" "ecs_task_log_group" {
  name              = "/ecs/hello-world-task"
  retention_in_days = 7 

  tags = {
    Name = "ecs-hello-world-log-group"
  }
}

# CloudWatch Metric Alarm
resource "aws_cloudwatch_metric_alarm" "ecs_service_error_alarm" {
  alarm_name          = "ecs-hello-world-error-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnhealthyHostCount" 
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0 # Trigger if there's any unhealthy tasks
  alarm_description   = "Alarm for unhealthy ECS tasks in hello-world service."
  
  dimensions = {
    TargetGroup = aws_lb_target_group.hello_world_tg.arn_suffix
    LoadBalancer = aws_lb.hello_world_alb.arn_suffix
  }

  actions_enabled = true 
  alarm_actions   = [aws_sns_topic.alarm_notifications.arn] 
  ok_actions = [aws_sns_topic.alarm_notifications.arn]

  tags = {
    Name = "ecs-hello-world-error-alarm"
  }
}

# SNS Topic for notifications 
resource "aws_sns_topic" "alarm_notifications" {
  name = "ecs-hello-world-alarms"
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.alarm_notifications.arn
  protocol  = "email"
  endpoint  = "mayangabbin@gmail.com"
}
