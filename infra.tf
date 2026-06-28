terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.53.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.6"
    }
  }
}

provider "aws" {}

# AMI

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*"]
  }
}

# SSH

resource "tls_private_key" "ssh" {
  # algorithm = "ED25519"

  # Use RSA if ED25519 is not compatible (ED25519 is more secure)
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ssh" {
  key_name   = "ssh"
  public_key = tls_private_key.ssh.public_key_openssh
}

output "private_key" {
  value     = tls_private_key.ssh.private_key_openssh
  sensitive = true
}

# Nodes

locals {
  control_plane_nodes = {
    "controlplane1" = {
      security_group_ids = [
        aws_security_group.node_firewall.id,
        aws_security_group.control_plane_firewall.id
      ]
    }
    # "controlplane2" = {
    #   security_group_ids = [
    #     aws_security_group.node_firewall.id,
    #     aws_security_group.control_plane_firewall.id
    #   ]
    # }
  }
  worker_nodes = {
    "worker1" = {
      security_group_ids = [
        aws_security_group.node_firewall.id,
        aws_security_group.worker_firewall.id
      ]
    }
    # "worker2" = {
    #   security_group_ids = [
    #     aws_security_group.node_firewall.id,
    #     aws_security_group.worker_firewall.id
    #   ]
    # }
    # "worker3" = {
    #   security_group_ids = [
    #     aws_security_group.node_firewall.id,
    #     aws_security_group.worker_firewall.id
    #   ]
    # }
  }
  nodes = merge(local.control_plane_nodes, local.worker_nodes)
}

resource "aws_instance" "nodes" {
  for_each = local.nodes

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t4g.small"
  vpc_security_group_ids = each.value.security_group_ids
  key_name               = aws_key_pair.ssh.key_name
  iam_instance_profile   = aws_iam_instance_profile.ssm.name

  # Terminate the instance after 3 hours in case you forget the cluster running.
  user_data = <<-EOF
    #!/bin/bash
    shutdown -h +180
  EOF

  tags = {
    Name = each.key
  }
}

output "nodes" {
  value = {
    for key in keys(local.nodes) : key => {
      public_ip   = aws_instance.nodes[key].public_ip
      instance_id = aws_instance.nodes[key].id
    }
  }
}

output "control_plane_nodes" {
  value = {
    for key in keys(local.control_plane_nodes) : key => {
      public_ip   = aws_instance.nodes[key].public_ip
      instance_id = aws_instance.nodes[key].id
    }
  }
}

output "worker_nodes" {
  value = {
    for key in keys(local.worker_nodes) : key => {
      public_ip   = aws_instance.nodes[key].public_ip
      instance_id = aws_instance.nodes[key].id
    }
  }
}

# Default VPC

resource "aws_default_vpc" "default" {}

# Firewall rules for every node in the cluster

resource "aws_security_group" "node_firewall" {
  name        = "node_firewall"
  description = "Firewall rules for every node in the cluster"
  vpc_id      = aws_default_vpc.default.id
}

resource "aws_vpc_security_group_ingress_rule" "kubelet" {
  security_group_id = aws_security_group.node_firewall.id
  cidr_ipv4         = aws_default_vpc.default.cidr_block
  ip_protocol       = "tcp"
  from_port         = 10250
  to_port           = 10250
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.node_firewall.id
  cidr_ipv4         = "0.0.0.0/0" # TODO use local ip address?
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "internet" {
  security_group_id = aws_security_group.node_firewall.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = -1
}

# Firewall rules for control-plane node

resource "aws_security_group" "control_plane_firewall" {
  name        = "control_plane_firewall"
  description = "Firewall rules for control-plane node"
  vpc_id      = aws_default_vpc.default.id
}

resource "aws_vpc_security_group_ingress_rule" "api_server" {
  security_group_id = aws_security_group.control_plane_firewall.id
  # cidr_ipv4         = aws_default_vpc.default.cidr_block
  cidr_ipv4   = "0.0.0.0/0" # TODO use local ip address?
  ip_protocol = "tcp"
  from_port   = 6443
  to_port     = 6443
}

resource "aws_vpc_security_group_ingress_rule" "etcd" {
  security_group_id = aws_security_group.control_plane_firewall.id
  cidr_ipv4         = aws_default_vpc.default.cidr_block
  ip_protocol       = "tcp"
  from_port         = 2379
  to_port           = 2379
}

resource "aws_vpc_security_group_ingress_rule" "etcd_peer" {
  security_group_id = aws_security_group.control_plane_firewall.id
  cidr_ipv4         = aws_default_vpc.default.cidr_block
  ip_protocol       = "tcp"
  from_port         = 2380
  to_port           = 2380
}

resource "aws_vpc_security_group_ingress_rule" "scheduler" {
  security_group_id = aws_security_group.control_plane_firewall.id
  cidr_ipv4         = aws_default_vpc.default.cidr_block
  ip_protocol       = "tcp"
  from_port         = 10251
  to_port           = 10251
}

resource "aws_vpc_security_group_ingress_rule" "controller_manager" {
  security_group_id = aws_security_group.control_plane_firewall.id
  cidr_ipv4         = aws_default_vpc.default.cidr_block
  ip_protocol       = "tcp"
  from_port         = 10252
  to_port           = 10252
}

# Firewall rules for worker nodes

resource "aws_security_group" "worker_firewall" {
  name        = "worker_firewall"
  description = "Firewall rules for worker nodes"
  vpc_id      = aws_default_vpc.default.id
}

resource "aws_vpc_security_group_ingress_rule" "services" {
  security_group_id = aws_security_group.worker_firewall.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 30000
  to_port           = 32767
}

# Endpoints

locals {
  kubernetes_endpoint = "https://${aws_instance.nodes["controlplane1"].public_ip}:6443"
  service_endpoint    = "http://${aws_instance.nodes["worker1"].public_ip}"
}

output "kubernetes_endpoint" {
  value = local.kubernetes_endpoint
}

output "service_endpoint" {
  value = local.service_endpoint
}

# SSM

resource "aws_iam_role" "ssm" {
  name = "ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name = "ec2-ssm-profile"
  role = aws_iam_role.ssm.name
}
