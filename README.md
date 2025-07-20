# CloudRide Challenge: ECS Fargate Deployment with Terraform & GitHub Actions

## Overview

This repository contains a sample web application ("Hello World") deployed to AWS ECS using **Terraform** and an automated CI/CD pipeline with **GitHub Actions**.

## Repository Structure
```bash
├── .github/                
│   └── workflows/
│       └── deploy-ecs.yml   # CI/CD pipeline for building, pushing, and deploying to ECS
├── terraform/               # Terraform configuration files for AWS infrastructure
│   ├── network.tf           # VPC, Subnets, Internet Gateway, Route Tables
│   ├── github_iam.tf        # IAM roles and OIDC provider for GitHub Actions
│   ├── ecs.tf               # ECS Cluster, Service, Task Definition, ECR, ALB
│   ├── monitoring.tf        # CloudWatch alarms and notifications
│   ├── providers.tf         # Providers configuration
│   └── vpc_endpoints.tf     # VPC Endpoints
├── hello-world/             # The web application and its Dockerfile
│   ├── index.html           # Simple "Hello World" web page
│   └── Dockerfile           # Dockerfile for building the application image
└── README.md                # This README file
```

## Core Components & Architecture

### Networking
**(Defined in `terraform/network.tf`)**
* **VPC:** a secure and private environment for our resources.
* **Internet Gateway:** Enables communication between resources in our VPC and the internet.
* **Availability Zones Data Source :** Dynamically fetches a list of available Availability Zones in our region. This ensures our infrastructure is deployed across multiple AZs for high availability without specifying AZ names.
* **Public Subnets (x2):** Subnets for resources that require direct internet access. Automatically assigns a public IP address to new instances.
* **Private Subnets (x2):** Subnets for application tasks, isolating them from direct internet ingress.
* **Route Tables:**
    * **Public Route Table:** Routes internet-bound traffic from public subnets via the IGW.
    * **Private Route Table:** Routes traffic within the VPC for private subnets.
* **Route Table Associations:**
    * **Public Route Table Associations:** Associates the public subnets with the public route table
    * **Private Route Table Associations:** Aassociates the private subnets with the private route table
      
### ECS Services & Components
**(Defined in `terraform/ecs.tf`)**
* **Elastic Container Registry (ECR) Repository:** A repository (hello-world-app) for storing our Docker image.
* **Elastic Container Service (ECS) Cluster:** A logical grouping of tasks or services.
* **IAM Role for ECS Tasks:** grants the necessary permissions to the ECS agent and tasks for actions like pulling Docker images from ECR and pushing container logs to CloudWatch.
* **Security Group for ALB:** Controls inbound and outbound network traffic for the Application Load Balancer. Allows HTTP inbound traffic from anywhere and permits all outbound traffic.
* **Security Group for ECS Tasks ecurity Group for ECS Tasks :** Controls inbound and outbound network traffic for your ECS tasks. Only allows HTTP inbound traffic specifically from the ALB's security group.ש 
* **Application Load Balancer (ALB):** Distributes incoming application traffic across multiple targets (our ECS tasks), ensuring high availability and fault tolerance.
* **ALB Target Group:** A logical grouping of targets (ECS tasks) that the ALB routes traffic to.
* **ALB Listener:** Listens for connection requests onHTTP port 80, and forwards them to the the hello_world_tg target group.
* **ECS Task Definition:** A blueprint for our application, specifying:
    * The Docker image to use (initiall image, will be updated by CI/CD).
    * CPU and memory allocation.
    * Port mappings, essential flag, and logging configuration.
    * `awsvpc` network mode (required for Fargate).
    * **Task Execution Role:** An IAM role allowing ECS to pull images from ECR and publish logs to CloudWatch.
* **ECS Service:** Manages the running tasks based on the task definition, ensuring that 2 instances are always running. Tasks will be placed in our private sunets and won't recieve public IPs. 
* **Auto Scaling for ECS Service:** Automatically adjusts the number of tasks in the ECS service based on demand- aims to maintain an average CPU utilization of 50%. our min task capacity is 2 and max is 5. 

### Monitoring
**(Defined in `terraform/monitoring.tf`)**
* **CloudWatch Log Group for ECS Task Logs:** A dedicated log group in CloudWatch where logs from our ECS tasks will be stored.
* **CloudWatch Metric Alarm:** This alarm monitors the health of our tasks as reported by the ALB. It triggers when any of your tasks become unhealthy.
*  **SNS Topic Subscription:** Subscribes an endpoint (my email address) to the SNS topic. When a message is published to ecs-hello-world-alarms.
  
### VPC Endpoints
**(Defined in `terraform/vpc_endpoints.tf`)**
* **Security Group for VPC Endpoints:** Controls network access to the VPC Endpoints. Allows inbound HTTPS traffic only from the ECS Tasks.
* **VPC Endpoints:** Endpoints who provide a private connection to ECR API, ECR Docker Registry, and Amazon S3, in order to pull images succussfully and to CloudWatch Logs in order to push logs.

### Access Management for Github Actions
**(Defined in `terraform/github_iam.tf`)**
* **GitHub Actions OIDC Provider Thumbprint:** Dynamically fetches the current thumbprint from GitHub's OIDC provider URL.
* **IAM OIDC Identity Provider:** Establishes a trust relationship between our AWS account and GitHub's OIDC provider.
* **IAM Role for GitHub Actions Deployment:** IAM role for GitHub Actions to assume.
* **IAM Role Policy Attachment for ECR:** Povides comprehensive permissions for ECR, allowing the workflow to authenticate with ECR, push Docker images, and pull existing images.
* **IAM Role Policy Attachment for ECS:** Grants broad permissions for managing ECS resources. 
