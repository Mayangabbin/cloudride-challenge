# AWS Provider
provider "aws" {
  region = "eu-west-1"
}

# TLS Provider (for fetching Github OIDC thumbprint)
provider "tls" {}
