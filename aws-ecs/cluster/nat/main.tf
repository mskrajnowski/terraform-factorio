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

module "instance" {
  source = "./instance"

  name          = var.name
  tags          = var.tags
  vpc_id        = var.vpc_id
  subnet_ids    = var.subnet_ids
  instance_type = var.instance_type

  config_param_name = aws_ssm_parameter.config.name
}

# Create a lambda which will setup started NAT instances
module "setup_lambda_package" {
  source = "github.com/codequest-eu/terraform-modules?ref=a69fb11//zip"

  directory                  = "${path.module}/setup_lambda/src"
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
    ROUTER_EIP_ID   = aws_eip.this.id
    ROUTER_ASG      = module.instance.asg_name
    ROUTE_TABLE_IDS = join(",", var.private_route_table_ids)
  }

  policy_arns = { self = aws_iam_policy.setup_lambda.arn }
}
