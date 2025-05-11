data "aws_subnets" "base_subnets" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  tags = var.subnet_tags
}

data "aws_vpc" "base" {
  id = var.vpc_id
}

data "aws_region" "this" {}

data "cloudinit_config" "slurm_userdata_control_node" {
  base64_encode = true
  part {
    content_type = "text/x-shellscript"
    content      = file("${path.module}/template/userdata_common.sh")
  }
  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/template/userdata_control_node.tpl", {
      aws_region      = data.aws_region.this.name
      pubkey_content  = tls_private_key.ssh_key.public_key_openssh
      privkey_content = tls_private_key.ssh_key.private_key_pem
      authkey_content = file("~/.ssh/id_rsa.pub")
    })
  }
}

data "cloudinit_config" "slurm_userdata_compute_node" {
  base64_encode = true
  part {
    content_type = "text/x-shellscript"
    content      = file("${path.module}/template/userdata_common.sh")
  }
  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/template/userdata_compute_node.tpl", {
      aws_region     = data.aws_region.this.name
      pubkey_content = tls_private_key.ssh_key.public_key_openssh
    })
  }
}

data "aws_ami" "slurm_node_ami" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
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

data "aws_instances" "asg_members" {
  depends_on = [aws_autoscaling_group.slurm_compute_nodegroup_asg]
  for_each   = local.compute_node
  filter {
    name   = "tag:nodegroup"
    values = [each.key]
  }
  #filter {
  #  name   = "instance-state-name"
  #  values = ["running"]
  #}
}
