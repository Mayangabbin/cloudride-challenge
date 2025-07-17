# AWS Provider
provider "aws" {
  region = "eu-west-1"
}

# TLS Provider (for fetching OIDC thumbprint)
provider "tls" {}
