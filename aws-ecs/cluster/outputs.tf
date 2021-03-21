output "name" {
  value = aws_ecs_cluster.this.name
}

output "arn" {
  value = aws_ecs_cluster.this.arn
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnets
}

output "private_route_table_ids" {
  value = module.vpc.private_route_table_ids
}

output "public_subnet_ids" {
  value = module.vpc.public_subnets
}

output "nat_security_group_id" {
  value = module.nat.security_group_id
}

output "nat_ip" {
  value = module.nat.ip
}

output "instance_asg_id" {
  value = module.instances.asg_id
}

output "instances_asg_arn" {
  value = module.instances.asg_arn
}

output "instance_subnet_ids" {
  value = module.instances.subnet_ids
}

output "instance_security_group_id" {
  value = module.instances.security_group_id
}
