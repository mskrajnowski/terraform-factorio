variable "name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "cluster_name" { type = string }
variable "cluster_arn" { type = string }
variable "private_route_table_ids" { type = list(string) }

variable "host_security_group_id" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "instance_type" {
  type    = string
  default = "t3a.nano"
}