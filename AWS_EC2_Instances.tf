locals {
  control_plane_count = 1
  worker_count        = 1

  nodes = merge(
    { for i in range(local.control_plane_count) : "controlplane${i + 1}" => { role = "control-plane" } },
    { for i in range(local.worker_count) : "worker${i + 1}" => { role = "worker" } },
  )

  ec2_instance_type = "t4g.small"

  kubernetes_version = "1.36"

  ubuntu_release = {
    version  = "26.04"
    codename = "resolute"
  }
}

data "aws_ami" "this" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-${local.ubuntu_release.codename}-${local.ubuntu_release.version}-arm64-server-*"]
  }
}

resource "aws_instance" "this" {
  for_each = local.nodes

  tags = { Name = each.key }

  ami           = data.aws_ami.this.id
  instance_type = local.ec2_instance_type

  vpc_security_group_ids = {
    "control-plane" = [
      aws_security_group.this["node-firewall"].id,
      aws_security_group.this["control-plane-firewall"].id,
    ]
    "worker" = [
      aws_security_group.this["node-firewall"].id,
      aws_security_group.this["worker-firewall"].id,
    ]
  }[each.value.role]

  user_data = <<-EOF
    #cloud-config

    hostname: ${each.key}

    ssh_authorized_keys:
      - ${var.ssh_authorized_key}

    runcmd:
      # Disable swap
      - swapoff -a
      - sed -ri '/\sswap\s/s/^([^#])/# \1/' /etc/fstab

      # Load kernel modules
      - touch /etc/modules-load.d/k8s.conf
      - echo "overlay"      >> /etc/modules-load.d/k8s.conf
      - echo "br_netfilter" >> /etc/modules-load.d/k8s.conf
      - modprobe overlay
      - modprobe br_netfilter

      # Load kernel parameters
      - touch /etc/sysctl.d/k8s.conf
      - echo "net.bridge.bridge-nf-call-iptables  = 1" >> /etc/sysctl.d/k8s.conf
      - echo "net.bridge.bridge-nf-call-ip6tables = 1" >> /etc/sysctl.d/k8s.conf
      - echo "net.ipv4.ip_forward                 = 1" >> /etc/sysctl.d/k8s.conf
      - sysctl --system

      # Add Docker APT repository and signing key
      - echo "deb [signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${local.ubuntu_release.codename} stable" > /etc/apt/sources.list.d/docker.list
      - curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
      - chmod 0644 /etc/apt/keyrings/docker.asc

      # Add Kubernetes APT repository and signing key
      - echo "deb [signed-by=/etc/apt/keyrings/kubernetes.asc] https://pkgs.k8s.io/core:/stable:/v${local.kubernetes_version}/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
      - curl -fsSL https://pkgs.k8s.io/core:/stable:/v${local.kubernetes_version}/deb/Release.key -o /etc/apt/keyrings/kubernetes.asc
      - chmod 0644 /etc/apt/keyrings/kubernetes.asc

      # Update APT package index
      - apt update

      # Install containerd
      - apt install -y containerd.io

      # Install Kubernetes packages and pin versions
      - apt install -y kubelet kubeadm kubectl
      - apt-mark hold kubelet kubeadm kubectl

      # Configure and restart containerd
      - sh -c 'containerd config default | sed "s/SystemdCgroup = false/SystemdCgroup = true/" > /etc/containerd/config.toml'
      - systemctl restart containerd

      # Enable and start kubelet
      - systemctl enable --now kubelet
  EOF
}
