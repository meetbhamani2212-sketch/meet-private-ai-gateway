variable "aws_region" {
  type        = string
  description = "AWS region to deploy into."
  default     = "ca-central-1"
}

variable "project_name" {
  type        = string
  description = "Project name prefix for resources."
  default     = "meet-private-ai-gateway"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR."
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidr" {
  type        = string
  description = "Private subnet CIDR that will be advertised via Tailscale subnet routing."
  default     = "10.0.2.0/24"
}

variable "public_subnet_cidr" {
  type        = string
  description = "Public subnet CIDR (for subnet router EC2)."
  default     = "10.0.1.0/24"
}

variable "allowed_ssh_cidr" {
  type        = string
  description = "Optional: your public IP in CIDR notation for temporary SSH access to the router (leave empty to disable SSH)"
  default     = ""
}
