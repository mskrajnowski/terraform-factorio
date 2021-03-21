resource "aws_ssm_parameter" "config" {
  name  = "${var.name}-config"
  tags  = var.tags
  type  = "String"
  value = jsonencode([])

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_eip" "this" {
  vpc  = true
  tags = var.tags
}

# Create an ASG which will keep one NAT instance alive
resource "aws_autoscaling_group" "this" {
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
    id      = aws_launch_template.this.id
    version = aws_launch_template.this.latest_version
  }
}

# Fetch an Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.0.*-x86_64-ebs"]
  }
}

resource "aws_launch_template" "this" {
  name = var.name
  tags = var.tags

  update_default_version = true

  image_id               = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.this.id]

  user_data = base64encode(
    templatefile("${path.module}/scripts/userdata", {
      scripts = {
        update_iptables = file("${path.module}/scripts/update-iptables"),
        update          = templatefile("${path.module}/scripts/update", { config_param_name = aws_ssm_parameter.config.name })
      }
    })
  )

  iam_instance_profile {
    arn = aws_iam_instance_profile.this.arn
  }
}

resource "aws_security_group" "this" {
  name   = var.name
  tags   = var.tags
  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "out_any" {
  security_group_id = aws_security_group.this.id
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

resource "aws_security_group_rule" "in_ec2_connect" {
  security_group_id = aws_security_group.this.id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_blocks       = data.aws_ip_ranges.ec2_connect.cidr_blocks
}

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

resource "aws_iam_instance_profile" "this" {
  name = var.name
  role = aws_iam_role.this.name
}

data "aws_iam_policy_document" "get_config" {
  statement {
    actions   = ["ssm:GetParameter"]
    resources = ["arn:*:ssm:*:*:parameter/${aws_ssm_parameter.config.name}"]
  }
}

resource "aws_iam_role_policy" "get_config" {
  role   = aws_iam_role.this.name
  name   = "get-config"
  policy = data.aws_iam_policy_document.get_config.json
}

# Create a lambda which will setup any started NAT instances
module "setup_lambda_package" {
  source = "github.com/codequest-eu/terraform-modules?ref=a69fb11//zip"

  directory                  = "${path.module}/setup/src"
  directory_include_patterns = ["**/*.js"]

  output_path = "${path.module}/tmp/${var.name}-setup.{hash}.zip"
}

data "aws_iam_policy_document" "setup_lambda" {
  # https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazonec2.html
  statement {
    actions = ["ec2:AssociateAddress"]
    resources = [
      "arn:*:ec2:*:*:elastic-ip/${aws_eip.this.id}",
      "arn:*:ec2:*:*:instance/*",
    ]
  }

  statement {
    actions   = ["ec2:ModifyInstanceAttribute"]
    resources = ["*"]
  }

  statement {
    actions = ["ec2:CreateRoute", "ec2:ReplaceRoute"]
    resources = concat(
      [for id in var.private_route_table_ids : "arn:*:ec2:*:*:route-table/${id}"],
      ["arn:*:ec2:*:*:instance/*"]
    )
  }

  statement {
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "setup_lambda" {
  name   = "${var.name}-setup"
  policy = data.aws_iam_policy_document.setup_lambda.json
}

module "setup_lambda" {
  source = "github.com/codequest-eu/terraform-modules?ref=a69fb11//lambda"

  name         = "${var.name}-setup"
  package_path = module.setup_lambda_package.output_path
  runtime      = "nodejs14.x"
  handler      = "index.handler"
  timeout      = 30

  environment_variables = {
    NAT_EIP_ID      = aws_eip.this.id
    NAT_ASG         = aws_autoscaling_group.this.name
    ROUTE_TABLE_IDS = join(",", var.private_route_table_ids)
  }

  policy_arns = { self = aws_iam_policy.setup_lambda.arn }
}
