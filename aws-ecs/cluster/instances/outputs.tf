output "capacity_provider_name" {
  value = aws_ecs_capacity_provider.this.name
}

output "asg_id" {
  value = aws_autoscaling_group.this.id
}

output "asg_arn" {
  value = aws_autoscaling_group.this.arn
}

output "security_group_id" {
  value = aws_security_group.this.id
}

output "subnet_ids" {
  value = var.subnet_ids
}
