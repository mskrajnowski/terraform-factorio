provider "aws" {
  region = "eu-central-1"
}

locals {
  name = "terraform-factorio-aws-ecs-example"
}

module "cluster" {
  source = "../cluster"

  name = local.name
}

output "cluster" {
  value = module.cluster
}

module "router" {
  source = "../router"

  name = "${local.name}-router"

  vpc_id                  = module.cluster.vpc_id
  subnet_ids              = module.cluster.public_subnet_ids
  cluster_name            = module.cluster.name
  cluster_arn             = module.cluster.arn
  host_security_group_id  = module.cluster.host_security_group_id
  private_route_table_ids = module.cluster.private_route_table_ids
}

output "router" {
  value = module.router
}

resource "aws_s3_bucket" "seeds" {
  bucket = "${local.name}-seeds"
  acl    = "private"
}

resource "aws_s3_bucket_object" "seed_save" {
  bucket = aws_s3_bucket.seeds.bucket
  key    = "save.zip"
  source = "${path.module}/save.zip"
  etag   = filemd5("${path.module}/save.zip")
}

module "server" {
  source = "../server"

  name = "${local.name}-server"

  cluster_name             = module.cluster.name
  vpc_id                   = module.cluster.vpc_id
  host_subnet_ids          = module.cluster.host_subnet_ids
  host_security_group_id   = module.cluster.host_security_group_id
  router_port              = 34197
  router_rcon_port         = 27015
  router_security_group_id = module.router.security_group_id

  settings        = { name = "Example Server" }
  admins          = ["mskrajnowski"]
  allowed_players = ["mskrajnowski"]
  seed_save       = aws_s3_bucket_object.seed_save
}

output "server_address" {
  value = "${module.router.ip}:34197"
}

output "server_rcon_address" {
  value = "${module.router.ip}:27015"
}

output "server" {
  value     = module.server
  sensitive = true
}
