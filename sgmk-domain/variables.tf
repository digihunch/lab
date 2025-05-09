variable "project_name" {
  description = "Name of the project, used for resource naming"
  type        = string
  default     = "sagemaker-domain-project"
}

variable "domain_name" {
  description = "Name of the SageMaker domain"
  type        = string
  default     = "sagemaker-domain"
}

variable "vpc_id" {
  description = "ID of existing VPC to use"
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "List of existing subnet IDs to use"
  type        = list(string)
  default     = null
}

variable "iam_idc_group_display_names" {
  description = "IAM Identity Center group name to assign the SageMaker domain with"
  type        = list(string)
  default     = ["SageMakerUserGroup"]
} 
