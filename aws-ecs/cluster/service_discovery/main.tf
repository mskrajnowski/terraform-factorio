module "lambda_package" {
  source = "github.com/codequest-eu/terraform-modules?ref=a69fb11//zip"

  directory                  = "${path.module}/lambda/src"
  directory_include_patterns = ["**/*.js"]

  output_path = "${path.module}/tmp/${var.name}.{hash}.zip"
}

data "aws_iam_policy_document" "lambda" {
  # https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazonelasticcontainerservice.html
  statement {
    actions = [
      "ecs:DescribeContainerInstances",
      "ecs:ListTasks",
      "ecs:DescribeTasks",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "ecs:cluster"
      values   = ["arn:*:ecs:*:*:cluster/${var.cluster_name}"]
    }
  }

  statement {
    actions   = ["ecs:DescribeTaskDefinition"]
    resources = ["*"]
  }

  # https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazonec2.html
  statement {
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"]
  }

  # https://docs.aws.amazon.com/service-authorization/latest/reference/list_awssystemsmanager.html
  statement {
    actions   = ["ssm:PutParameter"]
    resources = ["arn:*:ssm:*:*:parameter/${var.nat_config_param_name}"]
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
  timeout      = 30

  environment_variables = {
    CLUSTER             = var.cluster_name
    ROUTER_CONFIG_PARAM = var.nat_config_param_name
  }

  policy_arns = { self = aws_iam_policy.lambda.arn }
}

