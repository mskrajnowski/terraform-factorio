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
      values   = [var.cluster_arn]
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
    actions   = ["ssm:GetParameter", "ssm:PutParameter"]
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
    CLUSTER          = var.cluster_name
    NAT_CONFIG_PARAM = var.nat_config_param_name
  }

  policy_arns = { self = aws_iam_policy.lambda.arn }
}

# Launch lambda function when ECS task state changes
resource "aws_cloudwatch_event_rule" "task_state_changed" {
  name = var.name

  # https://docs.aws.amazon.com/AmazonCloudWatch/latest/events/CloudWatchEventsandEventPatterns.html
  # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs_cwe_events.html
  event_pattern = jsonencode({
    source      = ["aws.ecs"],
    detail-type = ["ECS Task State Change"],
    detail = {
      clusterArn = [var.cluster_arn]
    }
  })
}

resource "aws_cloudwatch_event_target" "lambda" {
  arn  = module.lambda.arn
  rule = aws_cloudwatch_event_rule.task_state_changed.id
}

resource "aws_lambda_permission" "task_state_changed" {
  function_name = module.lambda.name
  action        = "lambda:InvokeFunction"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.task_state_changed.arn
}
