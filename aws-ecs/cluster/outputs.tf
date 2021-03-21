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

output "host_subnet_ids" {
  value = aws_autoscaling_group.spot.vpc_zone_identifier
}

output "name" {
  value = aws_ecs_cluster.cluster.name
}

output "arn" {
  value = aws_ecs_cluster.cluster.arn
}

output "host_asg_id" {
  value = aws_autoscaling_group.spot.id
}

output "host_asg_arn" {
  value = aws_autoscaling_group.spot.arn
}

output "host_security_group_id" {
  value = aws_security_group.host.id
}
