# ------------------------------------------------
# NEW: Security Group for VPC Endpoints
# ------------------------------------------------
resource "aws_security_group" "vpce_sg" {
  vpc_id      = aws_vpc.main.id
  name        = "ecs-hello-world-vpce-sg"
  description = "Security group for ECR VPC Endpoints"

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks_sg.id] # Allow inbound from ECS Tasks SG
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecs-hello-world-vpce-sg"
  }
}

# ------------------------------------------------
# NEW: VPC Endpoints (ECR API, ECR DKR, S3)
# ------------------------------------------------

# VPC Endpoint for ECR API
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.eu-west-1.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpce_sg.id] # Use the new VPCE SG
  subnet_ids          = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name = "ecs-hello-world-ecr-api-vpce"
  }
}

# VPC Endpoint for ECR DKR (Docker Registry)
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.eu-west-1.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpce_sg.id] # Use the new VPCE SG
  subnet_ids          = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name = "ecs-hello-world-ecr-dkr-vpce"
  }
}

# VPC Endpoint for S3 (Gateway Endpoint)
# This routes S3 traffic through the endpoint using the private route table
resource "aws_vpc_endpoint" "s3" {
  vpc_id        = aws_vpc.main.id
  service_name  = "com.amazonaws.eu-west-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [
    aws_route_table.private.id
  ]

  tags = {
    Name = "ecs-hello-world-s3-vpce"
  }
}

# VPC Endpoint for CloudWatch Logs
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.eu-west-1.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpce_sg.id]
  subnet_ids          = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name = "ecs-hello-world-logs-vpce"
  }
}
