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

  ssh_username = "ubuntu"
  source_ami_filter {
    filters = {
      virtualization-type = "hvm"
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
    script = "provisioner-script.sh"
  }
}
