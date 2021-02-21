provider "aws" {
  region = "eu-central-1"
}

module "cluster" {
  source = "../cluster"

  name = "terraform-factorio-aws-ecs-example"
}

output "cluster" {
  value = module.cluster
}
