output "ip" {
  value = module.eip.ip
}

output "eip_id" {
  value = module.eip.id
}

output "security_group_id" {
  value = module.instance.security_group_id
}

output "role_name" {
  value = module.instance.role_name
}

output "role_arn" {
  value = module.instance.role_arn
}

output "instance_user_data" {
  value = module.instance.user_data
}

output "config_param_name" {
  value = aws_ssm_parameter.config.name
}
