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

  cluster_name           = module.cluster.name
  vpc_id                 = module.cluster.vpc_id
  host_subnet_ids        = module.cluster.host_subnet_ids
  host_security_group_id = module.cluster.host_security_group_id

  settings        = { name = "Example Server" }
  admins          = ["mskrajnowski"]
  allowed_players = ["mskrajnowski"]
  seed_save       = aws_s3_bucket_object.seed_save
}

output "server" {
  value     = module.server
  sensitive = true
}
