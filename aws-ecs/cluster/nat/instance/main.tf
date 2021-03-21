# Create an ASG which will keep exactly 1 router alive
resource "aws_autoscaling_group" "router" {
  name = var.name
  tags = [for key, value in var.tags : {
    key                 = key
    value               = value
    propagate_at_launch = true
  }]

  min_size         = 1
  desired_capacity = 1
  max_size         = 1

  vpc_zone_identifier = var.subnet_ids

  launch_template {
    id      = aws_launch_template.router.id
    version = aws_launch_template.router.latest_version
  }
}

# The router is an amazon linux 2 instance
data "aws_ami" "amazon_linux" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.0.*-x86_64-ebs"]
  }
}

locals {
  user_data = <<-EOT
    #!/bin/bash

    set -ex

    yum install -y ec2-instance-connect jq

    # install aws cli 2
    # https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-linux.html
    cd /tmp
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install
    rm -rf awscliv2.zip aws

    aws --version

    # setup NAT
    cat >/etc/sysctl.d/50-port-forwarding.conf <<-'EOF'
      net.ipv4.ip_forward=1
      net.ipv4.conf.eth0.send_redirects = 0
    EOF
    sysctl -p
    sysctl --system

    iptables \
      --table nat \
      --append POSTROUTING \
      --out-interface eth0 \
      --jump MASQUERADE

    # install /opt/ecs-router scripts
    mkdir -p /opt/ecs-router
    cd /opt/ecs-router

    cat >update-iptables <<-'EOF'
      ${indent(2, file("${path.module}/bin/update-iptables"))}
    EOF

    cat >update <<-'EOF'
      #!/bin/bash

      aws ssm get-parameter \
        --name '${var.config_param_name}' \
        --query 'Parameter.Value' \
        --output text \
      | /opt/ecs-router/update-iptables
    EOF

    chmod +x update-iptables update
  EOT
}

output "user_data" {
  value = local.user_data
}

resource "aws_launch_template" "router" {
  name = var.name
  tags = var.tags

  update_default_version = true

  image_id               = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.router.id]

  user_data = base64encode(local.user_data)

  iam_instance_profile {
    arn = aws_iam_instance_profile.router.arn
  }
}

# Create a security group for the router, which
# - allows EC2 instance connect
# - allows all outbound traffic
resource "aws_security_group" "router" {
  name   = var.name
  tags   = var.tags
  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "router_out_any" {
  security_group_id = aws_security_group.router.id
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

resource "aws_security_group_rule" "router_in_ec2_instance_connect" {
  security_group_id = aws_security_group.router.id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_blocks       = data.aws_ip_ranges.ec2_connect.cidr_blocks
}

# Create IAM role and instance profile for the router
data "aws_iam_policy_document" "router_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "router" {
  name = var.name
  tags = var.tags

  assume_role_policy = data.aws_iam_policy_document.router_assume_role.json
}

resource "aws_iam_instance_profile" "router" {
  name = var.name
  role = aws_iam_role.router.name
}

data "aws_iam_policy_document" "router_config" {
  statement {
    actions   = ["ssm:GetParameter"]
    resources = [var.config_param_arn]
  }
}

resource "aws_iam_role_policy" "router_config" {
  role   = aws_iam_role.router.name
  name   = "config"
  policy = data.aws_iam_policy_document.router_config.json
}


