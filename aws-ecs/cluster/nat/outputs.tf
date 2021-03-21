output "ip" {
  value = aws_eip.this.public_ip
}

output "eip_id" {
  value = aws_eip.this.id
}

output "security_group_id" {
  value = aws_security_group.this.id
}

output "role_name" {
  value = aws_iam_role.this.name
}

output "role_arn" {
  value = aws_iam_role.this.arn
}

output "config_param_name" {
  value = aws_ssm_parameter.config.name
}
