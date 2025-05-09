# AWS SageMaker Domain Terraform Configuration

This Terraform configuration creates an AWS SageMaker domain with the necessary networking components and IAM roles.

## Prerequisites

- Terraform installed (version 1.0.0 or later)
- AWS CLI configured with appropriate credentials
- AWS account with permissions to create SageMaker domains

## Resources Created

- VPC with DNS support
- Subnet in the specified availability zone
- Security group with necessary rules for SageMaker
- IAM role and policy for SageMaker
- SageMaker domain with default user and space settings

## Usage

1. Initialize Terraform:
   ```bash
   terraform init
   ```

2. Review the planned changes:
   ```bash
   terraform plan
   ```

3. Apply the configuration:
   ```bash
   terraform apply
   ```

4. To destroy the resources:
   ```bash
   terraform destroy
   ```

## Variables

The following variables can be customized by creating a `terraform.tfvars` file:

- `aws_region`: AWS region to deploy resources (default: us-west-2)
- `project_name`: Name of the project, used for resource naming (default: sagemaker-domain)
- `domain_name`: Name of the SageMaker domain (default: sagemaker-domain)
- `vpc_cidr`: CIDR block for the VPC (default: 10.0.0.0/16)
- `subnet_cidr`: CIDR block for the subnet (default: 10.0.1.0/24)
- `availability_zone`: Availability zone for the subnet (default: us-west-2a)

## Outputs

The configuration provides the following outputs:

- `domain_id`: The ID of the SageMaker domain
- `domain_arn`: The ARN of the SageMaker domain
- `vpc_id`: The ID of the VPC
- `subnet_id`: The ID of the subnet
- `security_group_id`: The ID of the security group
- `iam_role_arn`: The ARN of the IAM role

## Notes

- The configuration creates a VPC with public subnet access
- The security group allows inbound HTTPS (443) traffic
- The IAM role includes permissions for SageMaker and ECR operations
- The domain is configured with IAM authentication mode 