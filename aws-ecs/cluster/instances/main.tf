# Create a capacity provider for an ECS cluster which will manage the ASG desired_capacity
resource "aws_ecs_capacity_provider" "this" {
  name = var.name
  tags = var.tags

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.this.arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      status                    = "ENABLED"
      target_capacity           = 90
      maximum_scaling_step_size = 1
      minimum_scaling_step_size = 1
    }
  }
}

# Create an ASG which will manage the worker EC2 instances
resource "aws_autoscaling_group" "this" {
  name = var.name
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
  max_size         = var.max_size

  vpc_zone_identifier   = var.subnet_ids
  protect_from_scale_in = true

  launch_template {
    id      = aws_launch_template.this.id
    version = aws_launch_template.this.latest_version
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

# Fetch the latest Amazon Linux 2 ECS-optimized AMI
data "aws_ami" "amazon_linux_ecs" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-2.0.*-x86_64-ebs"]
  }
}

# Create a launch template for the ASG
resource "aws_launch_template" "this" {
  name = var.name
  tags = var.tags

  update_default_version = true

  image_id               = data.aws_ami.amazon_linux_ecs.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.this.id]

  user_data = base64encode(
    <<-EOT
      #!/bin/bash

      set -ex

      cat >/etc/ecs/ecs.config <<EOF
        ECS_CLUSTER=${var.cluster_name}
      EOF
    EOT
  )

  iam_instance_profile {
    arn = aws_iam_instance_profile.this.arn
  }

  instance_market_options {
    market_type = "spot"
  }
}

# Create a security group for the worker EC2 instances
resource "aws_security_group" "this" {
  name   = var.name
  tags   = var.tags
  vpc_id = var.vpc_id
}

# Allow any outbound traffic from worker instances
resource "aws_security_group_rule" "out_any" {
  security_group_id = aws_security_group.this.id
  type              = "egress"
  protocol          = "all"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}

# Create IAM role and instance profile for worker EC2 instances
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name = var.name
  tags = var.tags

  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_for_ec2" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "this" {
  name = var.name
  role = aws_iam_role.this.name
}
