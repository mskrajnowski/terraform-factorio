variable "name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "cluster_name" { type = string }
variable "nat_config_param_name" { type = string }
