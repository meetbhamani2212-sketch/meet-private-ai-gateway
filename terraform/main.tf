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

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "${var.project_name}-nat-gw"
  }

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route" "private_internet_via_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
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

# ------------------------------
# IAM Roles & Instance Profiles
# ------------------------------

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "router_role" {
  name               = "${var.project_name}-router-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "router_ssm" {
  role       = aws_iam_role.router_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "router_profile" {
  name = "${var.project_name}-router-profile"
  role = aws_iam_role.router_role.name
}

resource "aws_iam_role" "service_role" {
  name               = "${var.project_name}-service-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "service_ssm" {
  role       = aws_iam_role.service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Bedrock permissions
data "aws_iam_policy_document" "bedrock_invoke" {
  statement {
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "bedrock_invoke" {
  name        = "${var.project_name}-bedrock-invoke"
  description = "Allow private service to invoke Amazon Bedrock models"
  policy      = data.aws_iam_policy_document.bedrock_invoke.json
}

resource "aws_iam_role_policy_attachment" "service_bedrock" {
  role       = aws_iam_role.service_role.name
  policy_arn = aws_iam_policy.bedrock_invoke.arn
}

resource "aws_iam_role_policy_attachment" "service_marketplace_full" {
  role       = aws_iam_role.service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSMarketplaceFullAccess"
}

resource "aws_iam_instance_profile" "service_profile" {
  name = "${var.project_name}-service-profile"
  role = aws_iam_role.service_role.name
}

# --------------------------------------
# Tailscale resources (ACLs, auth keys)
# --------------------------------------

resource "tailscale_acl" "this" {
  acl = file("${path.module}/../acl/policy.hujson")
}

resource "tailscale_tailnet_key" "router" {
  reusable      = false
  ephemeral     = true
  preauthorized = true
  expiry        = 3600

  tags = ["tag:subnet-router"]

  depends_on = [tailscale_acl.this]
}

# ---------------------------------------------------
# EC2 instances (Router Instance + Service Instance)
# ---------------------------------------------------

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# Router EC2 Instance:
resource "aws_instance" "router" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.router.id]
  iam_instance_profile   = aws_iam_instance_profile.router_profile.name

  user_data = templatefile("${path.module}/userdata/router.sh", {
    TS_AUTHKEY     = tailscale_tailnet_key.router.key
    ADVERTISE_CIDR = var.private_subnet_cidr
    HOSTNAME       = "${var.project_name}-subnet-router"
  })

  tags = {
    Name = "${var.project_name}-tailscale-subnet-router"
    Role = "subnet-router"
  }
}

# Service EC2 Instance:
resource "aws_instance" "service" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.service.id]
  iam_instance_profile   = aws_iam_instance_profile.service_profile.name

  user_data = file("${path.module}/userdata/service.sh")

  tags = {
    Name = "${var.project_name}-private-api-service"
    Role = "private-service"
  }
}