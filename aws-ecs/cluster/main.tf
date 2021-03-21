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

resource "aws_ecs_cluster" "cluster" {
  name = var.name
  tags = var.tags

  capacity_providers = [aws_ecs_capacity_provider.spot.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.spot.name
  }

  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}

resource "aws_ecs_capacity_provider" "spot" {
  name = "${var.name}-spot"
  tags = var.tags

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.spot.arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      status                    = "ENABLED"
      target_capacity           = 90
      maximum_scaling_step_size = 1
      minimum_scaling_step_size = 1
    }
  }
}

# Create an ASG and a launch template which:
# - launch instances in the VPC public subnets
# - launch EC2 Spot instances to cut costs

resource "aws_autoscaling_group" "spot" {
  name = "${var.name}-spot"
  tags = concat(
    [for key, value in var.tags : {
      key                 = key
      value               = value
      propagate_at_launch = true
    }],
    [{
      key                 = "AmazonECSManaged"
      value               = ""
      propagate_at_launch = true
    }]
  )

  min_size         = 0
  desired_capacity = 0
  max_size         = 1

  vpc_zone_identifier   = module.vpc.private_subnets
  protect_from_scale_in = true

  launch_template {
    id      = aws_launch_template.host.id
    version = aws_launch_template.host.latest_version
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

data "aws_ami" "amazon_linux_ecs" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-2.0.*-x86_64-ebs"]
  }
}

resource "aws_launch_template" "host" {
  name = "${var.name}-host"
  tags = var.tags

  update_default_version = true

  image_id               = data.aws_ami.amazon_linux_ecs.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.host.id]

  user_data = base64encode(
    <<-EOT
      #!/bin/bash

      set -ex

      cat >/etc/ecs/ecs.config <<EOF
        ECS_CLUSTER=${var.name}
      EOF

      yum install -y ec2-instance-connect
    EOT
  )

  iam_instance_profile {
    arn = aws_iam_instance_profile.host.arn
  }

  instance_market_options {
    market_type = "spot"
  }
}

# Create a security group for the EC2 instances, which
# - allows all outbound traffic
# - allows EC2 instance connect

resource "aws_security_group" "host" {
  name   = "${var.name}-host"
  tags   = var.tags
  vpc_id = module.vpc.vpc_id
}

resource "aws_security_group_rule" "host_out_any" {
  security_group_id = aws_security_group.host.id
  type              = "egress"
  protocol          = "all"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}

data "aws_region" "current" {}

data "aws_ip_ranges" "ec2_connect" {
  regions  = [data.aws_region.current.name]
  services = ["ec2_instance_connect"]
}

resource "aws_security_group_rule" "host_in_ec2_instance_connect" {
  security_group_id = aws_security_group.host.id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_blocks       = data.aws_ip_ranges.ec2_connect.cidr_blocks
}

# Create IAM role and instance profile for EC2 instances

data "aws_iam_policy_document" "host_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "host" {
  name = "${var.name}-host"
  tags = var.tags

  assume_role_policy = data.aws_iam_policy_document.host_assume_role.json
}

resource "aws_iam_role_policy_attachment" "host_ecs_for_ec2" {
  role       = aws_iam_role.host.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "host" {
  name = "${var.name}-host"
  role = aws_iam_role.host.name
}
