# Create a vpc with public networks in 2 availability zones
data "aws_availability_zones" "default" {}

locals {
  vpc_cidr_block      = "10.0.0.0/16"
  azs                 = slice(data.aws_availability_zones.default.names, 0, 2)
  subnet_cidr_blocks  = cidrsubnets(local.vpc_cidr_block, 4, 4, 8, 8)
  private_cidr_blocks = slice(local.subnet_cidr_blocks, 0, 2)
  public_cidr_blocks  = slice(local.subnet_cidr_blocks, 2, 4)
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.name
  tags = var.tags

  cidr            = local.vpc_cidr_block
  azs             = local.azs
  private_subnets = local.private_cidr_blocks
  public_subnets  = local.public_cidr_blocks

  enable_dns_hostnames = true
  enable_nat_gateway   = false
}

# Create an ECS cluster with an ASG-based capacity provider
resource "aws_ecs_cluster" "this" {
  name = var.name
  tags = var.tags

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  capacity_providers = [module.instances.capacity_provider_name]

  default_capacity_provider_strategy {
    capacity_provider = module.instances.capacity_provider_name
  }
}

module "nat" {
  source = "./nat"

  name = "${var.name}-nat"

  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = module.vpc.public_subnets
  private_route_table_ids = module.vpc.private_route_table_ids
  cluster_name            = aws_ecs_cluster.this.name
}

module "service_discovery" {
  source = "./service_discovery"

  name = "${var.name}-service-discovery"
  tags = var.tags

  cluster_name          = aws_ecs_cluster.this.name
  nat_config_param_name = module.nat.config_param_name
}


module "instances" {
  source = "./instances"

  name = "${var.name}-instances"
  tags = var.tags

  instance_type = var.instance_type
  max_size      = var.max_instances

  cluster_name = var.name
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnets
}

# Allow NAT and instances to talk to each other
resource "aws_security_group_rule" "nat_in_instance" {
  security_group_id        = module.nat.security_group_id
  source_security_group_id = module.instances.security_group_id
  type                     = "ingress"
  protocol                 = -1
  from_port                = 0
  to_port                  = 0
}

resource "aws_security_group_rule" "instance_in_nat" {
  security_group_id        = module.instances.security_group_id
  source_security_group_id = module.nat.security_group_id
  type                     = "ingress"
  protocol                 = -1
  from_port                = 0
  to_port                  = 0
}
