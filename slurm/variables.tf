variable "resource_prefix" {
  type    = string
  default = "slurm"
}

variable "vpc_id" {
  type    = string
  default = "vpc-004646ac522c171c0"
}

variable "subnet_tags" {
  type = map(string)
  default = {
    Purpose = "Node"
  }
}
