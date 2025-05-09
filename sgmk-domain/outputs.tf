output "domain_id" {
  description = "The ID of the SageMaker domain"
  value       = aws_sagemaker_domain.teamdomain.id
}

output "domain_arn" {
  description = "The ARN of the SageMaker domain"
  value       = aws_sagemaker_domain.teamdomain.arn
}

output "security_group_id" {
  description = "The ID of the security group"
  value       = aws_security_group.sagemaker_sg.id
}

output "iam_role_arn" {
  description = "The ARN of the IAM role"
  value       = aws_iam_role.sagemaker_role.arn
} 