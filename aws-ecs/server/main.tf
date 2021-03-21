# Create EFS for persistent storage, eg. saves
resource "aws_security_group" "data" {
  name   = "${var.name}-data"
  tags   = var.tags
  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "data_in_host" {
  security_group_id        = aws_security_group.data.id
  source_security_group_id = var.host_security_group_id
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 2049
  to_port                  = 2049
}

resource "aws_efs_file_system" "data" {
  creation_token = "${var.name}-data"
  encrypted      = true
}

resource "aws_efs_mount_target" "data" {
  count = length(var.host_subnet_ids)

  file_system_id  = aws_efs_file_system.data.id
  subnet_id       = var.host_subnet_ids[count.index]
  security_groups = [aws_security_group.data.id]
}

# Create a CloudWatch log group for storing factorio server logs
resource "aws_cloudwatch_log_group" "server" {
  name              = var.name
  tags              = var.tags
  retention_in_days = 7
}

# Create an IAM role for the service

data "aws_iam_policy_document" "server_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "server" {
  name = var.name
  tags = var.tags

  assume_role_policy = data.aws_iam_policy_document.server_assume_role.json
}

data "aws_iam_policy_document" "server_seed" {
  count = var.seed_save != null ? 1 : 0

  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.seed_save.bucket}/${var.seed_save.key}"]
  }
}

resource "aws_iam_role_policy" "server_seed" {
  count = var.seed_save != null ? 1 : 0

  role   = aws_iam_role.server.name
  name   = "seed"
  policy = data.aws_iam_policy_document.server_seed[0].json
}

# Create the ECS task definition for the server

resource "random_password" "rcon" {
  count = var.rcon_password == null ? 1 : 0

  length = 16
}

locals {
  rcon_password = coalesce(var.rcon_password, random_password.rcon[0].result)

  seed_environment = var.seed_save != null ? {
    SEED_BUCKET = var.seed_save.bucket
    SEED_KEY    = var.seed_save.key
    SEED_RESET  = var.reset_save ? "true" : ""
  } : {}

  server_environment = {
    # TODO: move the password to a safer place
    FACTORIO_SERVER_RCON_PASSWORD = local.rcon_password

    FACTORIO_SERVER_SETTINGS  = jsonencode(merge(local.base_settings, var.settings))
    FACTORIO_SERVER_ADMINS    = jsonencode(var.admins)
    FACTORIO_SERVER_WHITELIST = jsonencode(var.allowed_players)
    FACTORIO_SERVER_BANLIST   = jsonencode(var.banned_players)
    FACTORIO_SERVER_RESET     = var.reset_save ? "true" : ""
    FACTORIO_SERVER_SEED      = var.seed_save == null ? "" : "true"
  }
}

data "aws_region" "current" {}

resource "aws_ecs_task_definition" "server" {
  family                   = var.name
  tags                     = var.tags
  requires_compatibilities = ["EC2"]
  task_role_arn            = aws_iam_role.server.arn

  container_definitions = jsonencode(concat(
    [
      {
        name              = "factorio"
        image             = "factoriotools/factorio:${var.factorio_version}"
        essential         = true
        memoryReservation = 512

        portMappings = [
          { protocol = "udp", containerPort = 34197, hostPort = var.host_port },
          { protocol = "tcp", containerPort = 27015, hostPort = var.host_rcon_port }
        ]

        environment = [
          for name, value in local.server_environment :
          { name = name, value = value }
        ]

        entryPoint = [
          "bash", "-c", <<-EOT
            set -e

            echo "Configuring the server..."
            mkdir -p "$CONFIG"
            echo -n "$FACTORIO_SERVER_SETTINGS" > "$CONFIG/server-settings.json"
            echo -n "$FACTORIO_SERVER_ADMINS" > "$CONFIG/server-adminlist.json"
            echo -n "$FACTORIO_SERVER_WHITELIST" > "$CONFIG/server-whitelist.json"
            echo -n "$FACTORIO_SERVER_BANLIST" > "$CONFIG/server-banlist.json"
            echo -n "$FACTORIO_SERVER_RCON_PASSWORD" > "$CONFIG/rconpw"

            if [[ -n "$FACTORIO_SERVER_RESET" ]]; then
              echo "Deleting existing saves..."
              rm -rf "$SAVES"
            fi

            echo "Creating saves and mods directories..."
            mkdir -p "$SAVES" "$MODS"

            if [[ -n "$FACTORIO_SERVER_SEED" ]]; then
              while [[ "$(find -L "$SAVES" -iname \*.zip -mindepth 1 | wc -l)" == 0 ]]; do
                echo "Waiting for the seed save..."
                sleep 1
              done
              echo "Save found"
            fi

            echo "Launching factorio server..."
            exec /docker-entrypoint.sh
          EOT
        ]

        mountPoints = [
          { sourceVolume = "data", containerPath = "/factorio" }
        ]

        logConfiguration = {
          logDriver = "awslogs",
          options = {
            "awslogs-group"         = aws_cloudwatch_log_group.server.name,
            "awslogs-region"        = data.aws_region.current.name,
            "awslogs-stream-prefix" = "ecs"
          }
        }
      }
    ],
    var.seed_save != null ? [{
      name              = "seed",
      image             = "amazon/aws-cli:2.1.27"
      essential         = false
      memoryReservation = 64

      environment = [
        for name, value in local.seed_environment :
        { name = name, value = value }
      ]

      entryPoint = ["bash", "-c"]
      command = [
        <<-EOT
          set -e

          SAVES=/factorio/saves
          MODS=/factorio/mods

          if [[ -n "$SEED_RESET" ]]; then
            echo "Deleting existing saves..."
            rm -rf "$SAVES"
          fi

          mkdir -p "$SAVES" "$MODS"

          if [[ "$(find -L "$SAVES" -iname \*.zip -mindepth 1 | wc -l)" == 0 ]]; then
            echo "Downloading the seed save '$SEED_BUCKET/$SEED_KEY'..."
            aws s3api get-object \
              --bucket "$SEED_BUCKET" \
              --key "$SEED_KEY" \
              "$SAVES/_autosave1.zip"
            echo "Seed save downloaded as '$SAVES/_autosave1.zip'"
          else
            echo "A save already exists, skipping seed save"
          fi
        EOT
      ]

      mountPoints = [
        { sourceVolume = "data", containerPath = "/factorio" }
      ]

      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.server.name,
          "awslogs-region"        = data.aws_region.current.name,
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }] : []
  ))

  volume {
    name = "data"

    efs_volume_configuration {
      file_system_id = aws_efs_file_system.data.id
      root_directory = "/"
    }
  }
}

resource "aws_ecs_service" "server" {
  depends_on = [aws_efs_mount_target.data]

  name = var.name
  tags = var.tags

  task_definition                    = aws_ecs_task_definition.server.arn
  cluster                            = var.cluster_name
  desired_count                      = 1
  launch_type                        = "EC2"
  propagate_tags                     = "SERVICE"
  deployment_minimum_healthy_percent = 0
}
