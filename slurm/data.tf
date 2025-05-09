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

data "aws_region" "this" {}

data "cloudinit_config" "slurm_userdata" {
  base64_encode = true
  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/template/userdata.tpl", {
      aws_region = data.aws_region.this.name
      pubkey_content = tls_private_key.ssh_key.public_key_openssh
    })
  }
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