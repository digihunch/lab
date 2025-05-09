terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {}

data "aws_caller_identity" "current" {}

data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}

resource "aws_kms_key" "SageMakerEncryptionKey" {
  description             = "This key is used for SageMaker to encrypt resources"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  key_usage = "ENCRYPT_DECRYPT"
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "SageMaker-KMS-KeyPolicy"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          "AWS" : [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
            "${data.aws_iam_session_context.current.issuer_arn}"
          ]
        }
        Action   = "kms:*"
        Resource = "*"
        }, {
        Sid    = "Allow SageMaker Serivce to use the key"
        Effect = "Allow"
        Principal = {
          "Service" : [
            "sagemaker.amazonaws.com"
          ]
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*",
        ]
        Resource = "*"
      },{
        Sid    = "Allow SageMaker principal to use the key"
        Effect = "Allow"
        Principal = {
          "AWS" : [
            aws_iam_role.sagemaker_role.arn
          ]
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*",
        ]
        Resource = "*"
      }
    ]
  })
  tags = { Name = "SageMaker-Custom-KMS-Key" }
}

resource "aws_kms_alias" "sgmk_kms_alias" {
  name = "alias/team-sagemaker-key"
  target_key_id = aws_kms_key.SageMakerEncryptionKey.key_id
}

# Security Group for SageMaker Domain
resource "aws_security_group" "sagemaker_sg" {
  name        = "${var.project_name}-sg"
  description = "Security group for SageMaker domain"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}

# IAM Role for SageMaker
resource "aws_iam_role" "sagemaker_role" {
  name = "${var.project_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sagemaker_managed_policy_attachment" {
  role       = aws_iam_role.sagemaker_role.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

# IAM Policy for SageMaker
resource "aws_iam_role_policy" "sagemaker_policy" {
  name = "${var.project_name}-policy"
  role = aws_iam_role.sagemaker_role.id
  # Policy must match the enabled tools, apps and instances
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:ListAliases",
          "kms:ListKeys"
        ]
        Resource = "*"
      }, {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:CreateGrant"
        ]
        Resource = aws_kms_key.SageMakerEncryptionKey.arn
      }
      #, {
      #  Sid = "DenyModelcreationIfNotOnVPC"
      #  Effect = "Deny"
      #  Action = [
      #    "sagemaker:CreateDomain",
      #    "sagemaker:UpdateDomain",
      #    "sagemaker:CreateDataQualityJobDefinition",
      #    "sagemaker:CreateOptimizationJob",
      #    "sagemaker:CreateEndpointConfig",
      #    "sagemaker:CreateHyperParameterTuningJob",
      #    "sagemaker:CreateModel",
      #    "sagemaker:CreateModelBiasJobDefinition",
      #    "sagemaker:CreateModelExplainabilityJobDefinition",
      #    "sagemaker:CreateModelQualityJobDefinition",
      #    "sagemaker:CreateMonitoringSchedule",
      #    "sagemaker:UpdateMonitoringSchedule",
      #    "sagemaker:CreateNotebookInstance",
      #    "sagemaker:CreateProcessingJob",
      #    "sagemaker:CreateTrainingJob",
      #  ]
      #  Resource = "*"
      #  Condition = {
      #    "BoolIfExists": {
      #      "sagemaker:VpcSubnets" = "false"
      #    }
      #  }
      #},{
      #  Sid = "DenyModelcreationIfAnySpecifiedSubnetIsNotIntended"
      #  Effect = "Deny"
      #  Action = [
      #    "sagemaker:CreateDomain",
      #    "sagemaker:UpdateDomain",
      #    "sagemaker:CreateDataQualityJobDefinition",
      #    "sagemaker:CreateOptimizationJob",
      #    "sagemaker:CreateEndpointConfig",
      #    "sagemaker:CreateHyperParameterTuningJob",
      #    "sagemaker:CreateModel",
      #    "sagemaker:CreateModelBiasJobDefinition",
      #    "sagemaker:CreateModelExplainabilityJobDefinition",
      #    "sagemaker:CreateModelQualityJobDefinition",
      #    "sagemaker:CreateMonitoringSchedule",
      #    "sagemaker:UpdateMonitoringSchedule",
      #    "sagemaker:CreateNotebookInstance",
      #    "sagemaker:CreateProcessingJob",
      #    "sagemaker:CreateTrainingJob",
      #  ]
      #  Resource = "*"
      #  Condition = {
      #    "ForAnyValue:StringNotEquals": {
      #      "sagemaker:VpcSubnets" = var.subnet_ids
      #    }
      #  }
      #}
    ]
  })
}

# SageMaker Domain
resource "aws_sagemaker_domain" "teamdomain" {
  domain_name = var.domain_name
  auth_mode   = "SSO"
  vpc_id      = var.vpc_id
  subnet_ids  = var.subnet_ids

  retention_policy {
    home_efs_file_system = "Delete"
  }

  default_space_settings {
    execution_role = aws_iam_role.sagemaker_role.arn

    space_storage_settings {
      default_ebs_storage_settings {
        default_ebs_volume_size_in_gb = 30
        maximum_ebs_volume_size_in_gb = 300
      }
    }

    security_groups = [aws_security_group.sagemaker_sg.id]

    jupyter_lab_app_settings {
      default_resource_spec {
        instance_type = "ml.t3.medium"
      }
    }
  }

  default_user_settings {
    execution_role = aws_iam_role.sagemaker_role.arn
    jupyter_lab_app_settings {
      app_lifecycle_management {
        idle_settings {
          idle_timeout_in_minutes = 60
          max_idle_timeout_in_minutes = 240
          min_idle_timeout_in_minutes = 60
        }
      }
    }

    security_groups = [aws_security_group.sagemaker_sg.id]

    sharing_settings {
      #s3_kms_key_id = 
      #s3_output_path = 
      notebook_output_option = "Disabled"
    }

    studio_web_portal = "ENABLED"
    default_landing_uri = "studio::"

    # https://docs.aws.amazon.com/sagemaker/latest/APIReference/API_StudioWebPortalSettings.html
    studio_web_portal_settings {
      hidden_instance_types = [
        "system",
        #"ml.t3.micro","ml.t3.small","ml.t3.medium","ml.t3.large","ml.t3.xlarge","ml.t3.2xlarge",
        #"ml.m5.large","ml.m5.xlarge","ml.m5.2xlarge","ml.m5.4xlarge","ml.m5.8xlarge","ml.m5.12xlarge","ml.m5.16xlarge","ml.m5.24xlarge",
        "ml.m5d.large","ml.m5d.xlarge","ml.m5d.2xlarge","ml.m5d.4xlarge","ml.m5d.8xlarge","ml.m5d.12xlarge","ml.m5d.16xlarge","ml.m5d.24xlarge",
        "ml.c5.large","ml.c5.xlarge","ml.c5.2xlarge","ml.c5.4xlarge","ml.c5.9xlarge","ml.c5.12xlarge","ml.c5.18xlarge","ml.c5.24xlarge",
        "ml.p3.2xlarge","ml.p3.8xlarge","ml.p3.16xlarge","ml.p3dn.24xlarge",
        #"ml.g4dn.xlarge","ml.g4dn.2xlarge","ml.g4dn.4xlarge","ml.g4dn.8xlarge","ml.g4dn.12xlarge","ml.g4dn.16xlarge",
        "ml.r5.large","ml.r5.xlarge","ml.r5.2xlarge","ml.r5.4xlarge","ml.r5.8xlarge","ml.r5.12xlarge","ml.r5.16xlarge","ml.r5.24xlarge",
        "ml.g5.xlarge","ml.g5.2xlarge","ml.g5.4xlarge","ml.g5.8xlarge","ml.g5.16xlarge","ml.g5.12xlarge","ml.g5.24xlarge","ml.g5.48xlarge",
        #"ml.g6.xlarge","ml.g6.2xlarge","ml.g6.4xlarge","ml.g6.8xlarge","ml.g6.12xlarge","ml.g6.16xlarge","ml.g6.24xlarge","ml.g6.48xlarge",
        "ml.g6e.xlarge","ml.g6e.2xlarge","ml.g6e.4xlarge","ml.g6e.8xlarge","ml.g6e.12xlarge","ml.g6e.16xlarge","ml.g6e.24xlarge","ml.g6e.48xlarge",
        "ml.p4d.24xlarge","ml.p4de.24xlarge",
        #"ml.trn1.2xlarge","ml.trn1.32xlarge","ml.trn1n.32xlarge",
        "ml.p5.48xlarge",
        "ml.m6i.large","ml.m6i.xlarge","ml.m6i.2xlarge","ml.m6i.4xlarge","ml.m6i.8xlarge","ml.m6i.12xlarge","ml.m6i.16xlarge","ml.m6i.24xlarge","ml.m6i.32xlarge",
        "ml.m7i.large","ml.m7i.xlarge","ml.m7i.2xlarge","ml.m7i.4xlarge","ml.m7i.8xlarge","ml.m7i.12xlarge","ml.m7i.16xlarge","ml.m7i.24xlarge","ml.m7i.48xlarge",
        "ml.c6i.large","ml.c6i.xlarge","ml.c6i.2xlarge","ml.c6i.4xlarge","ml.c6i.8xlarge","ml.c6i.12xlarge","ml.c6i.16xlarge","ml.c6i.24xlarge","ml.c6i.32xlarge",
        "ml.c7i.large","ml.c7i.xlarge","ml.c7i.2xlarge","ml.c7i.4xlarge","ml.c7i.8xlarge","ml.c7i.12xlarge","ml.c7i.16xlarge","ml.c7i.24xlarge","ml.c7i.48xlarge",
        "ml.r6i.large","ml.r6i.xlarge","ml.r6i.2xlarge","ml.r6i.4xlarge","ml.r6i.8xlarge","ml.r6i.12xlarge","ml.r6i.16xlarge","ml.r6i.24xlarge","ml.r6i.32xlarge",
        "ml.r7i.large","ml.r7i.xlarge","ml.r7i.2xlarge","ml.r7i.4xlarge","ml.r7i.8xlarge","ml.r7i.12xlarge","ml.r7i.16xlarge","ml.r7i.24xlarge","ml.r7i.48xlarge",
        "ml.m6id.large","ml.m6id.xlarge","ml.m6id.2xlarge","ml.m6id.4xlarge","ml.m6id.8xlarge","ml.m6id.12xlarge","ml.m6id.16xlarge","ml.m6id.24xlarge","ml.m6id.32xlarge",
        "ml.c6id.large","ml.c6id.xlarge","ml.c6id.2xlarge","ml.c6id.4xlarge","ml.c6id.8xlarge","ml.c6id.12xlarge","ml.c6id.16xlarge","ml.c6id.24xlarge","ml.c6id.32xlarge",
        "ml.r6id.large","ml.r6id.xlarge","ml.r6id.2xlarge","ml.r6id.4xlarge","ml.r6id.8xlarge","ml.r6id.12xlarge","ml.r6id.16xlarge","ml.r6id.24xlarge","ml.r6id.32xlarge",
      ]
      hidden_app_types = [
        "JupyterServer",
        #"KernelGateway",
        "DetailedProfiler",
        #"TensorBoard",
        #"CodeEditor",
        #"JupyterLab",
        "RStudioServerPro",
        "RSessionGateway",
        #"Canvas"
      ]
      hidden_ml_tools = [
        #"DataWrangler",
        #"FeatureStore",
        "EmrClusters", 
        #"AutoMl", 
        #"Experiments",
        #"Training",
        #"ModelEvaluation",
        #"Pipelines",
        #"Models",
        #"JumpStart",
        #"InferenceRecommender",
        #"Endpoints",
        #"Projects",
        #"InferenceOptimization",
        #"PerformanceEvaluation",
        "LakeraGuard",
        "Comet",
        "DeepchecksLLMEvaluation",
        "Fiddler",
        #"HyperPodClusters",
      ]
    }
  }

  
  app_network_access_type = "VpcOnly" # Default value is PublicInternetOnly which allows SageMaker to manage Internet access on its own. This must not be enabled in LZA where centralized Internet access is enabled.
  #app_security_group_management = "Customer"
  
  kms_key_id = aws_kms_key.SageMakerEncryptionKey.id
  tag_propagation = "ENABLED"


  domain_settings {
    security_group_ids = [aws_security_group.sagemaker_sg.id] # management security group

    docker_settings {
      enable_docker_access = "ENABLED"
      #vpc_only_trusted_accounts = [""]
    }
  }
  tags = {
    Name = var.domain_name
  }
}

data "aws_ssoadmin_instances" "iamidc_instance" {}

data "aws_identitystore_group" "iamidc_sagemaker_domain_groups" {
  for_each = toset(var.iam_idc_group_display_names)
  identity_store_id = tolist(data.aws_ssoadmin_instances.iamidc_instance.identity_store_ids)[0]
  # use external_id for external identity store
  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = each.value #var.iam_idc_group_display_name
    }
  }
}

resource "aws_ssoadmin_application_assignment" "teamdomain_group_assignments" {
  for_each = data.aws_identitystore_group.iamidc_sagemaker_domain_groups
  application_arn = aws_sagemaker_domain.teamdomain.single_sign_on_application_arn
  principal_id    = each.value.group_id
  principal_type  = "GROUP"
}

