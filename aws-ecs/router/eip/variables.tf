variable "name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "asg_name" { type = string }
variable "private_route_table_ids" { type = list(string) }
