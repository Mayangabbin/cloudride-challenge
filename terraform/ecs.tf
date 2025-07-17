
# ECR Repository
resource "aws_ecr_repository" "hello_world_app" {
  name                 = "hello-world-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "hello-world-app-ecr"
  }
}


# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "ecs-hello-world-cluster"

  tags = {
    Name = "ecs-hello-world-cluster"
  }
}

# IAM Role for ECS Tasks
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role-hello-world"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "ecs-task-execution-role-hello-world"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Security Group for ALB 
resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.main.id
  name   = "ecs-hello-world-alb-sg"
  description = "Allow HTTP access to ALB"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow HTTP from anywhere
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # All protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecs-hello-world-alb-sg"
  }
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs_tasks_sg" {
  vpc_id = aws_vpc.main.id
  name   = "ecs-hello-world-tasks-sg"
  description = "Allow HTTP access from ALB to ECS tasks"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.alb_sg.id] # Only allow traffic from ALB SG
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecs-hello-world-tasks-sg"
  }
}

# Application Load Balancer
resource "aws_lb" "hello_world_alb" {
  name               = "ecs-hello-world-alb"
  internal           = false 
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id] 

  enable_deletion_protection = false # when we go prod we'll change this

  tags = {
    Name = "ecs-hello-world-alb"
  }
}

# ALB Target Group
resource "aws_lb_target_group" "hello_world_tg" {
  name        = "ecs-hello-world-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip" # ECS Fargate uses IP targets

  health_check {
    path = "/"
    protocol = "HTTP"
    matcher = "200"
    interval = 30
    timeout = 5
    healthy_threshold = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "ecs-hello-world-tg"
  }
}

# ALB Listener (HTTP on port 80)
resource "aws_lb_listener" "hello_world_listener" {
  load_balancer_arn = aws_lb.hello_world_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.hello_world_tg.arn
  }

  tags = {
    Name = "ecs-hello-world-listener"
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "hello_world_task" {
  family                   = "hello-world-task"
  cpu                      = "256" 
  memory                   = "512" 
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name        = "hello-world-container"
      image       = "${aws_ecr_repository.hello_world_app.repository_url}:latest"
      cpu         = 256
      memory      = 512
      essential   = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/hello-world-task"
          "awslogs-region"        = "eu-west-1" 
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "hello-world-task-definition"
  }
}

# CloudWatch Log Group for ECS Task Logs
resource "aws_cloudwatch_log_group" "ecs_task_log_group" {
  name              = "/ecs/hello-world-task"
  retention_in_days = 7 # Adjust as needed

  tags = {
    Name = "ecs-hello-world-log-group"
  }
}

# ECS Service
resource "aws_ecs_service" "hello_world_service" {
  name            = "hello-world-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.hello_world_task.arn
  desired_count   = 2 # At least 2 running tasks
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.private_1.id, aws_subnet.private_2.id] # Tasks on private subnets
    security_groups = [aws_security_group.ecs_tasks_sg.id]
    assign_public_ip = false # Tasks do not need public IPs
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.hello_world_tg.arn
    container_name   = "hello-world-container"
    container_port   = 80
  }

  depends_on = [
    aws_lb_listener.hello_world_listener, # Ensure ALB listener is ready
    aws_iam_role_policy_attachment.ecs_task_execution_role_policy # Ensure IAM role is fully propagated
  ]

  tags = {
    Name = "hello-world-service"
  }
}

# ------------------------------------------------
# Auto Scaling for ECS Service
# ------------------------------------------------

resource "aws_appautoscaling_target" "ecs_service_scalable_target" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.hello_world_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = 2
  max_capacity       = 5
}

resource "aws_appautoscaling_policy" "ecs_service_cpu_scaling_policy" {
  name               = "ecs-cpu-scaling-policy"
  service_namespace  = "ecs"
  resource_id        = aws_appautoscaling_target.ecs_service_scalable_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service_scalable_target.scalable_dimension
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 50 # Scale up/down to maintain 50% CPU utilization
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

