# Step 3 will add:
# - VPC/Subnets/Route tables/Security Groups
# - EC2 instances (router + private service)
# - Tailscale tailnet key (auth key) resource

resource "aws_vpc" "placeholder" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "${var.project_name}-vpc"
  }
}
