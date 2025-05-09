variable "resource_prefix" {
  type    = string
  default = "base"
}

variable "vpc_id" {
  type = string
  default = "vpc-004646ac522c171c0"
}

variable "subnet_tags" {
  type = map(string)
  default = {
    Purpose = "Node"
  }
}

data aws_subnets base_subnets {
  filter {
    name = "vpc-id"
    values = [var.vpc_id]
  }
  tags = var.subnet_tags
}

data "aws_vpc" "base" {
  id = var.vpc_id
}

locals {
  control_node = {
    instance_type = "t3.medium"
  }
  compute_node = {
    node_group_1 = {
      instance_type = "t3.medium"
      size = 2
    }
    node_group_2 = {
      instance_type = "t3.medium"
      size = 2
    }
  }
}

data "aws_region" "this" {}

data "cloudinit_config" "slurm_userdata" {
  base64_encode = true
  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/template/userdata.tpl", {
      aws_region = data.aws_region.this.name
    })
  }
}

resource "aws_security_group" "slurm_node_sg" {
    name        = "${var.resource_prefix}-slurm-node-sg"
    description = "security group for slurm cluster nodes"
    vpc_id      = data.aws_vpc.base.id

  egress {
    description = "Outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Inbound Slurm"
    from_port = 6817
    to_port = 6818
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.base.cidr_block]
  }
  ingress {
    description = "Inbound SSH"
    from_port = 22
    to_port = 22
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.base.cidr_block]
  }
  tags = { Name = "${var.resource_prefix}-SlurmNodeSecurityGroup" }
}

resource "aws_iam_role" "slurm_instance_role" {
  name = "${var.resource_prefix}-slurm-inst-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Statement1"
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  tags = { Name = "${var.resource_prefix}-Slurm-Instance-Role" }
}

resource "aws_iam_role_policy_attachment" "slurm_role_ssm_policy_attachment" {
  role       = aws_iam_role.slurm_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "slurm_inst_profile" {
  name = "${var.resource_prefix}-slurm-inst-profile"
  role = aws_iam_role.slurm_instance_role.name
}

data "aws_ami" "slurm_node_ami" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_launch_template" "slurm_control_node_launch_template" {
  name          = "${var.resource_prefix}-slurm-control-node-launch-template"
  instance_type = local.control_node.instance_type
  user_data     = data.cloudinit_config.slurm_userdata.rendered
  image_id      = data.aws_ami.slurm_node_ami.id

  iam_instance_profile {
    name = aws_iam_instance_profile.slurm_inst_profile.name
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }
  block_device_mappings {
    device_name = data.aws_ami.slurm_node_ami.root_device_name
    ebs {
      volume_size = 100
      encrypted   = true
    }
  }
  vpc_security_group_ids = [aws_security_group.slurm_node_sg.id]
  tag_specifications {
    resource_type = "instance"
    tags = {
      prefix  = var.resource_prefix
      purpose = "slurm-control-node"
      Name    = "${var.resource_prefix}-control-node"
    }
  }
}

resource "aws_instance" "control_node" {
    ebs_optimized = true
    subnet_id = data.aws_subnets.base_subnets.ids[0]
    launch_template {
      id = aws_launch_template.slurm_control_node_launch_template.id
      version = "$Latest"
    }
}

resource "aws_launch_template" "slurm_compute_nodegroup_launch_template" {
    for_each = { for idx, rec in local.compute_node : idx => rec }
    name          = "${var.resource_prefix}-slurm-launch-template-${each.key}"
    instance_type = each.value.instance_type
    user_data     = data.cloudinit_config.slurm_userdata.rendered
    image_id      = data.aws_ami.slurm_node_ami.id

    iam_instance_profile {
        name = aws_iam_instance_profile.slurm_inst_profile.name
    }
    metadata_options {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
    }
    block_device_mappings {
        device_name = data.aws_ami.slurm_node_ami.root_device_name
        ebs {
            volume_size = 100
            encrypted   = true
        }
    } 
    vpc_security_group_ids = [aws_security_group.slurm_node_sg.id]
    tag_specifications {
        resource_type = "instance"
        tags = {
            prefix  = var.resource_prefix
            purpose = "slurm-control-node"
            Name    = "${var.resource_prefix}-control-node"
        }
    }
}

resource "aws_autoscaling_group" "slurm_compute_nodegroup_asg" {
    for_each = aws_launch_template.slurm_compute_nodegroup_launch_template
    vpc_zone_identifier = data.aws_subnets.base_subnets.ids
    desired_capacity    = local.compute_node[each.key].size
    max_size            = local.compute_node[each.key].size
    min_size            = local.compute_node[each.key].size
    name                = "${var.resource_prefix}-slurm-asg-${each.key}"

    launch_template {
        id      = aws_launch_template.slurm_compute_nodegroup_launch_template[each.key].id
        version = aws_launch_template.slurm_compute_nodegroup_launch_template[each.key].latest_version
    }
}
