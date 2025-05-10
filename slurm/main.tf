locals {
  control_node = {
    instance_type = "t3.medium"
  }
  compute_node = {
    node_group_1 = {
      instance_type = "t3.medium"
      size          = 2
    }
    node_group_2 = {
      instance_type = "t3.medium"
      size          = 2
    }
  }
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  filename = "${path.module}/out/id_rsa"
  content  = tls_private_key.ssh_key.private_key_pem
}

resource "local_file" "public_key" {
  filename = "${path.module}/out/id_rsa.pub"
  content  = tls_private_key.ssh_key.public_key_openssh
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
    from_port   = 6817
    to_port     = 6818
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.base.cidr_block]
  }
  ingress {
    description = "Inbound SSH"
    from_port   = 22
    to_port     = 22
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

resource "aws_launch_template" "slurm_control_node_launch_template" {
  name          = "${var.resource_prefix}-slurm-control-node-launch-template"
  instance_type = local.control_node.instance_type
  user_data     = data.cloudinit_config.slurm_userdata_control_node.rendered
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
  subnet_id     = data.aws_subnets.base_subnets.ids[0]
  launch_template {
    id      = aws_launch_template.slurm_control_node_launch_template.id
    version = "$Latest"
  }
  lifecycle {
    ignore_changes = [launch_template, user_data]
  }
}

resource "aws_launch_template" "slurm_compute_nodegroup_launch_template" {
  for_each      = { for idx, rec in local.compute_node : idx => rec }
  name          = "${var.resource_prefix}-slurm-launch-template-${each.key}"
  instance_type = each.value.instance_type
  user_data     = data.cloudinit_config.slurm_userdata_compute_node.rendered
  image_id      = data.aws_ami.slurm_node_ami.id

  iam_instance_profile {
    name = aws_iam_instance_profile.slurm_inst_profile.name
  }
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
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
      purpose = "slurm-compute-node"
      Name    = "${var.resource_prefix}-compute-${each.key}"
    }
  }
}

resource "aws_autoscaling_group" "slurm_compute_nodegroup_asg" {
  for_each            = aws_launch_template.slurm_compute_nodegroup_launch_template
  vpc_zone_identifier = data.aws_subnets.base_subnets.ids
  desired_capacity    = local.compute_node[each.key].size
  max_size            = local.compute_node[each.key].size
  min_size            = local.compute_node[each.key].size
  name                = "${var.resource_prefix}-slurm-asg-${each.key}"

  launch_template {
    id      = aws_launch_template.slurm_compute_nodegroup_launch_template[each.key].id
    version = aws_launch_template.slurm_compute_nodegroup_launch_template[each.key].latest_version
  }

  tag {
    key                 = "nodegroup"
    value               = each.key
    propagate_at_launch = true
  }
}

data "aws_instances" "asg_members" {
  for_each = local.compute_node
  filter {
    name   = "tag:nodegroup"
    values = [each.key]
  }
}

#locals {
#  provisioned_control_node  = "ip-${replace(aws_instance.control_node.private_ip, ".", "-")}"
#  provisioned_compute_nodes = { for k, v in data.aws_instances.asg_members : k => [for ip in v.private_ips : "ip-${replace(ip, ".", "-")}"] }
#}
#output "control_node" {
#  value = local.provisioned_control_node
#}
#output "compute_nodes" {
#  value = flatten([for ip in local.provisioned_compute_nodes : ip])
#}

resource "local_file" "slurm_conf" {
  filename = "${path.module}/out/slurm.conf"
  content = templatefile("${path.module}/template/slurm.conf.tpl", {
    controller_hostname  = "ip-${replace(aws_instance.control_node.private_ip, ".", "-")}"
    node_group_hostnames = { for k, v in data.aws_instances.asg_members : k => [for ip in v.private_ips : "ip-${replace(ip, ".", "-")}"] }
  })
  file_permission      = "0644"
  directory_permission = "0755"
}