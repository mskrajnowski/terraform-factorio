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

  name            = "${local.name}-server"
  cluster         = module.cluster
  nat_port        = 34197
  nat_rcon_port   = 27015
  settings        = { name = "Example Server" }
  admins          = ["mskrajnowski"]
  allowed_players = ["mskrajnowski"]
  seed_save       = aws_s3_bucket_object.seed_save
}

output "server_address" {
  value = module.server.address
}

output "server_rcon_address" {
  value = module.server.rcon_address
}

output "server_rcon_password" {
  value     = module.server.rcon_password
  sensitive = true
}
