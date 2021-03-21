variable "name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "cluster_name" { type = string }
variable "cluster_arn" { type = string }

variable "config_param_name" { type = string }
variable "config_param_arn" { type = string }
