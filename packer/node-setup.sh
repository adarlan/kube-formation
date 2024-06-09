#!/bin/bash
set -ex

# Disable swap memory
swapoff -a
sudo sed -i.bak -r 's/(.+ swap .+)/#\1/' /etc/fstab

# Load 'overlay' and 'br_netfilter' modules and configure them to load on boot
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# Once the modules above are loaded, set the following kernel parameters
# by configuring required sysctl to persist across system reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# To reload the configuration above
# Apply sysctl parameters without rebooting to the current running environment
sudo sysctl --system

# INSTALL CONTAINER RUNTIME

# We are going to use containerd
# https://github.com/containerd/containerd/blob/main/docs/getting-started.md

# Set up Docker's apt repository,
# because rhe containerd.io packages in DEB and RPM formats are distributed by Docker (not by the containerd project).
# The containerd.io package contains runc too, but does not contain CNI plugins (do we need to install it?).
# Ref: https://docs.docker.com/engine/install/ubuntu/

# Add Docker's official GPG key
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

# Install containerd packages
sudo apt-get install -y containerd.io

# Create a containerd configuration file
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml

# Set the cgroup driver for runc to systemd
# At the end of this section in /etc/containerd/config.toml
#       [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
#       ...
# Change the value for SystemCgroup from false to true
#             SystemdCgroup = true
# Using sed to swap it out in the file without editing it manually
sudo sed -i 's/            SystemdCgroup = false/            SystemdCgroup = true/' /etc/containerd/config.toml

# Restart containerd with the new configuration
sudo systemctl restart containerd

# INSTALL KUBEADM, KUBELET AND KUBECTL

# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/

# These instructions are for Kubernetes v1.30

# Update the apt package index and install packages needed to use the Kubernetes apt repository
sudo apt-get update
# apt-transport-https may be a dummy package; if so, you can skip that package
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# Download the public signing key for the Kubernetes package repositories. The same signing key is used for all repositories so you can disregard the version in the URL
# If the directory `/etc/apt/keyrings` does not exist, it should be created before the curl command
# sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add the appropriate Kubernetes apt repository
# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Update the apt package index, install kubelet, kubeadm and kubectl, and pin their version
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# (Optional) Enable the kubelet service before running kubeadm
sudo systemctl enable --now kubelet
# The kubelet is now restarting every few seconds, as it waits in a crashloop for kubeadm to tell it what to do
