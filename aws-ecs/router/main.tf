resource "aws_ssm_parameter" "config" {
  name  = "${var.name}-config"
  tags  = var.tags
  type  = "String"
  value = jsonencode([])

  lifecycle {
    ignore_changes = [value]
  }
}

module "instance" {
  source = "./instance"

  name                   = var.name
  tags                   = var.tags
  host_security_group_id = var.host_security_group_id
  vpc_id                 = var.vpc_id
  subnet_ids             = var.subnet_ids
  instance_type          = var.instance_type

  config_param_name = aws_ssm_parameter.config.name
  config_param_arn  = aws_ssm_parameter.config.arn
}

module "eip" {
  source = "./eip"

  name = "${var.name}-ip"
  tags = var.tags

  asg_name = module.instance.asg_name

  private_route_table_ids = var.private_route_table_ids
}

module "discovery" {
  source = "./discovery"

  name = "${var.name}-discovery"
  tags = var.tags

  cluster_name      = var.cluster_name
  cluster_arn       = var.cluster_arn
  config_param_name = aws_ssm_parameter.config.name
  config_param_arn  = aws_ssm_parameter.config.arn
}
