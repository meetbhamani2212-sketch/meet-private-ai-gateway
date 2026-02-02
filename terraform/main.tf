data "aws_availability_zones" "available" {
  state = "available"
}

# --------------------------
# Networking: VPC + Subnets
# --------------------------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet"
    Tier = "public"
  }
}

resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.private_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-private-subnet"
    Tier = "private"
  }
}

# --------------------------
# Routing
# --------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# --------------------------
# Security Groups
# --------------------------

# Router SG:
# - outbound open (router needs to reach Tailscale control plane)
# - inbound disabled by default
# - optional SSH can be temporarily enabled by setting allowed_ssh_cidr (not set by default)
resource "aws_security_group" "router" {
  name        = "${var.project_name}-router-sg"
  description = "Security group for Tailscale subnet router"
  vpc_id      = aws_vpc.this.id

  # Optional SSH access (only if allowed_ssh_cidr provided)
  dynamic "ingress" {
    for_each = var.allowed_ssh_cidr != "" ? [1] : []
    content {
      description = "Temporary SSH access"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [var.allowed_ssh_cidr]
    }
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-router-sg"
  }
}

# Service SG:
# - inbound ONLY from router SG on port 8000 (FastAPI)
# - outbound open ( for package installs / Bedrock call)
resource "aws_security_group" "service" {
  name        = "${var.project_name}-service-sg"
  description = "Security group for private FastAPI service"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "FastAPI only from subnet router"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.router.id]
  }

  egress {
    description = "Allow all outbound (restricted later)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-service-sg"
  }
}

