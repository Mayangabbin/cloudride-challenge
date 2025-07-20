# fetch the thumbprint for the GitHub Actions OIDC provider
data "tls_certificate" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

# IAM OIDC Identity Provider for GitHub Actions
resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_actions.certificates[0].sha1_fingerprint]

  tags = {
    Name = "github-actions-oidc-provider"
  }
}

# IAM Role for GitHub Actions to deploy to ECS
resource "aws_iam_role" "github_actions_ecs_deploy_role" {
  name = "github-actions-ecs-deploy-role"

  # Trust policy allowing GitHub Actions to assume this role via OIDC
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:sub" : "repo:Mayangabbin/cloudride-challenge:ref:refs/heads/main",
            "token.actions.githubusercontent.com:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name = "github-actions-ecs-deploy-role"
  }
}

# Allows pushing and pulling images from ECR
resource "aws_iam_role_policy_attachment" "github_actions_ecr_poweruser_policy" {
  role       = aws_iam_role.github_actions_ecs_deploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

# Allows full access to ECS
resource "aws_iam_role_policy_attachment" "github_actions_ecs_fullaccess_policy" {
  role       = aws_iam_role.github_actions_ecs_deploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
}
