variable "name" {
  type        = string
  description = "Base name for resources."
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

variable "max_size" {
  type        = number
  description = "Maximum number of EC2 instances to launch"
  default     = 1
}

variable "cluster_name" {
  type        = string
  description = "Name of the ECS cluster to register the instances with"
}

variable "vpc_id" {
  type        = string
  description = "Id of the VPC instances will be launched in"
}

variable "subnet_ids" {
  type        = list(string)
  description = "VPC subnet ids to launch instances in"
}
