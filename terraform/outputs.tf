output "aws_region" {
  value = var.aws_region
}

output "private_subnet_cidr" {
  value = var.private_subnet_cidr
}

output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}

output "router_sg_id" {
  value = aws_security_group.router.id
}

output "service_sg_id" {
  value = aws_security_group.service.id
}

output "router_public_ip" {
  value = aws_instance.router.public_ip
}

output "service_private_ip" {
  value = aws_instance.service.private_ip
}
