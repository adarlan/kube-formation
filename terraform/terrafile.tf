# data "aws_ami" "ubuntu" {
#   most_recent = true

#   filter {
#     name   = "name"
#     values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*"]
#   }

#   filter {
#     name   = "virtualization-type"
#     values = ["hvm"]
#   }

#   owners = ["099720109477"] # Canonical
# }

data "aws_ami" "node_image" {
  # executable_users = ["self"]
  most_recent      = true
  # name_regex       = "^myami-\\d{3}"
  owners           = ["self"]

  filter {
    name   = "name"
    values = ["my-k8s-ami-*"]
  }
}

resource "aws_instance" "nodes" {
  for_each = {

    "control-plane" = {
      security_group_ids = [
        aws_security_group.node_firewall.id,
        aws_security_group.control_plane_firewall.id
      ]
    }

    "worker-1" = {
      security_group_ids = [
        aws_security_group.node_firewall.id,
        aws_security_group.worker_firewall.id
      ]
    }

    "worker-2" = {
      security_group_ids = [
        aws_security_group.node_firewall.id,
        aws_security_group.worker_firewall.id
      ]
    }
  }

  ami           = data.aws_ami.node_image.id
  instance_type = "t4g.small"

  tags = {
    Name = each.key
  }

  vpc_security_group_ids = each.value.security_group_ids

  user_data = file("user-data.sh")

  key_name = aws_key_pair.ssh_key.key_name
}

resource "aws_key_pair" "ssh_key" {
  key_name   = "cluster_nodes_key"
  public_key = file("id_rsa.pub")
}

resource "aws_default_vpc" "default" {
  # tags = {
  #   Name = "Default VPC"
  # }
}
