packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
  }
}

source "amazon-ebs" "ubuntu" {

  ami_name = "my-k8s-ami-${formatdate("YYYY-MM-DD-hh-mm", timestamp())}"
  region   = "us-east-1"

  # Canonical, Ubuntu, 24.04 LTS, arm64 noble image build on 2024-04-23
  // source_ami   = "ami-0eac975a54dfee8cb"
  ssh_username = "ubuntu"
  source_ami_filter {
    filters = {
      virtualization-type = "hvm"
      // name = "ubuntu/images/*ubuntu-xenial-16.04-amd64-server-*"
      name = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*"
      root-device-type = "ebs"
    }
    owners = ["099720109477"] # Canonical
    most_recent = true
  }

  instance_type = "t4g.small"
}

build {

  name    = "my-k8s-ami-build"
  sources = ["source.amazon-ebs.ubuntu"]

  provisioner "shell" {
    script = "node-setup.sh"
  }
}
