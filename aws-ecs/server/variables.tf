variable "name" {
  type        = string
  description = "ECS service name and a base name for other resources"
}

variable "tags" {
  type        = map(string)
  description = "Tags to assign to resources"
  default     = {}
}

variable "start" {
  type        = bool
  description = "Whether to actually start the server"
  default     = true
}

variable "factorio_version" {
  type        = string
  description = "Factorio server version"
  default     = "1.1.27"
}

variable "settings" {
  type        = any
  description = "Factorio server settings"
  default     = {}
}

variable "admins" {
  type        = list(string)
  description = "Usernames of players that should have admin privileges"
  default     = []
}

variable "allowed_players" {
  type        = list(string)
  description = "Usernames of players that are allowed to join the server"
  default     = []
}

variable "banned_players" {
  type        = list(string)
  description = "Usernames of players that are banned from the server"
  default     = []
}

variable "seed_save" {
  type = object({
    bucket = string
    key    = string
  })
  description = "Bucket name and key of the save file to bootstrap the server with"
  default     = null
}

variable "reset_save" {
  type        = bool
  description = "Whether to delete all saves and create a new one"
  default     = false
}

variable "rcon_password" {
  type        = string
  description = "RCON password"
  default     = null
  sensitive   = true
}

variable "cluster_name" {
  type        = string
  description = "ECS cluster name"
}

variable "host_subnet_ids" {
  type        = list(string)
  description = "Cluster host subnet ids"
}

variable "host_security_group_id" {
  type        = string
  description = "ECS instances security group id"
}

variable "host_port" {
  type        = number
  description = "Port on the host to expose the server's main UDP port"
  default     = null
}

variable "host_rcon_port" {
  type        = number
  description = "Port on the host to expose the server's RCON TCP port"
  default     = null
}

variable "router_port" {
  type        = number
  description = "Port on the router to expose the server's main UDP port"
  default     = null
}

variable "router_rcon_port" {
  type        = number
  description = "Port on the router to expose the server's RCON TCP port"
  default     = null
}

variable "router_security_group_id" {
  type        = string
  description = "Router security group to add ingress rules to"
  default     = null
}

variable "vpc_id" {
  type        = string
  description = "Cluster VPC id"
}


