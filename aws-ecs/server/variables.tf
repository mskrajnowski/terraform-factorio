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
  default     = "1.1.30"
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

variable "nat_port" {
  type        = number
  description = "Port on the NAT instance to expose the server's main UDP port"
}

variable "nat_rcon_port" {
  type        = number
  description = "Port on the NAT instance to expose the server's RCON TCP port"
  default     = null
}

variable "cluster" {
  type = object({
    name                       = string
    instance_subnet_ids        = list(string)
    instance_security_group_id = string
    nat_security_group_id      = string
    nat_ip                     = string
    vpc_id                     = string
  })
  description = "Cluster to create the server in"
}
