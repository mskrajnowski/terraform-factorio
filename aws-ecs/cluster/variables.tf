variable "name" {
  type        = string
  description = "Name for the ECS cluster and a base name for other resources."
}

variable "tags" {
  type        = map(string)
  description = "Tags to assign to resources"
  default     = {}
}

variable "instance_type" {
  type        = string
  description = "Type of EC2 instances to launch"
  default     = "t2.small"
}

variable "max_instances" {
  type        = number
  description = "Maximum number of EC2 instances to launch"
  default     = 1
}
