provider "aws" {
  region = var.aws_region
}

provider "tailscale" {
  # Uses environment variable TAILSCALE_API_KEY
}