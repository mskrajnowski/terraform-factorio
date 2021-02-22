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

resource "aws_security_group_rule" "host_server_port" {
  security_group_id = module.cluster.host_security_group_id
  type              = "ingress"
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 34197
  to_port           = 34197
}

module "server" {
  source = "../server"

  name = "terraform-factorio-aws-ecs-example-server"

  cluster_name           = module.cluster.name
  vpc_id                 = module.cluster.vpc_id
  subnet_ids             = module.cluster.public_subnet_ids
  host_security_group_id = module.cluster.host_security_group_id
  host_port              = 34197

  settings        = { name = "Example Server" }
  admins          = ["mskrajnowski"]
  allowed_players = ["mskrajnowski"]
}

output "server" {
  value     = module.server
  sensitive = true
}
