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
