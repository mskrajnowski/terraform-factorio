resource "aws_eip" "router" {
  vpc  = true
  tags = var.tags
}

module "lambda_package" {
  source = "github.com/codequest-eu/terraform-modules?ref=a69fb11//zip"

  directory                  = "${path.module}/lambda/src"
  directory_include_patterns = ["**/*.js"]

  output_path = "${path.module}/tmp/${var.name}.{hash}.zip"
}

data "aws_iam_policy_document" "lambda" {
  # https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazonec2.html
  statement {
    actions = ["ec2:AssociateAddress"]
    resources = [
      "arn:*:ec2:*:*:elastic-ip/${aws_eip.router.id}",
      "arn:*:ec2:*:*:instance/*",
    ]
  }

  statement {
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "lambda" {
  name   = var.name
  policy = data.aws_iam_policy_document.lambda.json
}

module "lambda" {
  source = "github.com/codequest-eu/terraform-modules?ref=a69fb11//lambda"

  name         = var.name
  package_path = module.lambda_package.output_path
  runtime      = "nodejs14.x"
  handler      = "index.handler"

  environment_variables = {
    ROUTER_EIP_ID = aws_eip.router.id
    ROUTER_ASG    = var.asg_name
  }

  policy_arns = { self = aws_iam_policy.lambda.arn }
}
