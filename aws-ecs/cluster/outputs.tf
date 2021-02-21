output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnets
}

output "name" {
  value = aws_ecs_cluster.cluster.name
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
