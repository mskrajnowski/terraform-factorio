variable "name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "asg_name" { type = string }
