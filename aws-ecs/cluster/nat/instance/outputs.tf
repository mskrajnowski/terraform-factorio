output "asg_name" {
  value = aws_autoscaling_group.router.name
}

output "asg_arn" {
  value = aws_autoscaling_group.router.arn
}

output "security_group_id" {
  value = aws_security_group.router.id
}

output "role_name" {
  value = aws_iam_role.router.name
}

output "role_arn" {
  value = aws_iam_role.router.arn
}
