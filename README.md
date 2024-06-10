# Kube Formation

This project is designed to help you practice and understand the Kubernetes architecture by setting up a cluster using kubeadm on Amazon EC2 instances. The project leverages the following tools:

- Packer: For creating immutable AMIs for the cluster nodes.
- Terraform: For provisioning the EC2 instances as infrastructure-as-code.
- Ansible: For initializing and configuring the Kubernetes cluster.

#

docker run -it --rm -v $(pwd):/wd -w /wd alpine sh
apk add ansible openssh-client

mkdir ~/.ssh
ssh-keyscan $SERVER_IP > ~/.ssh/known_hosts
chmod 644 ~/.ssh/known_hosts
eval $(ssh-agent -s)
chmod 400 $PRIVATE_KEY
ssh-add $PRIVATE_KEY
echo $SERVER_IP > hosts
cp $ACME_JSON ./acme.json
ansible-playbook -i hosts -u ubuntu playbook.yml

#

Shutdown the instances every 5 hours in case you forget the cluster running
echo "0 */5 * * * root /sbin/shutdown -h now" >> /etc/crontab

one control-plane node
two worker nodes

2 GB RAM
2 CPUs

OS: Ubuntu

control-plane firewall rules
api-server          6443
etcd                2379
kubelet             10250
scheduler           10251
controller-manager  10252

worker nodes firewall rules
kubelet             10250
services            30000-32767

## 1

disable swap memory:

swapoff -a
sudo sed -i.bak -r 's/(.+ swap .+)/#\1/' /etc/fstab

<!-- be sure that br_netfilter module is loaded:

lsmod | grep br_netfilter

If the module name don't display in the previous command output, run the following command to load the module:

sudo modprobe br_netfilter -->

Load two modules in the current running environment and configure them to load on boot

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

Once this module is loaded, set the following IPv6 kernel parameters to 1
(Configure required sysctl to persist across system reboots)

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

To reload the configuration above, run the following command:
(Apply sysctl parameters without rebooting to the current running environment)

sudo sysctl --system

## 2 Install container runtime

https://github.com/containerd/containerd/blob/main/docs/getting-started.md

Set up Docker's apt repository, because rhe containerd.io packages in DEB and RPM formats are distributed by Docker (not by the containerd project).
The containerd.io package contains runc too, but does not contain CNI plugins (do we need to install it?).

https://docs.docker.com/engine/install/ubuntu/

```bash
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
```

Install containerd packages

sudo apt-get install -y containerd.io

Create a containerd configuration file

sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml

Set the cgroup driver for runc to systemd
At the end of this section in /etc/containerd/config.toml
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
      ...
Change the value for SystemCgroup from false to true
            SystemdCgroup = true
Use sed to swap it out in the file without editing it manually
sudo sed -i 's/            SystemdCgroup = false/            SystemdCgroup = true/' /etc/containerd/config.toml

Restart containerd with the new configuration

sudo systemctl restart containerd

## 3 Installing kubeadm, kubelet and kubectl

https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/

These instructions are for Kubernetes v1.30

```shell
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
```

<!-- OLD

sudo apt-get update && sudo apt-get install -y apt-transport-https curl

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

Enable and start kubelet service:

sudo systemctl daemon-reload
sudo systemctl enable kubelet
sudo systemctl restart kubelet
sudo systemctl status kubelet -->

## 4 initialize control-plane

Run this command only on control-plane node:
It takes many arguments, but to keep it simple, let's run without any argument:

```shell
kubeadm init
```

It will display some commands to run on nodes.

## 5 Install pod-network addon

CNI

We will use the Weavenet CNI plugin

We will use kubectl to install the addon, so let's configure it first:
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"

## 6 Join worker nodes

kubeadm join ...

If you loose the join command, go to the control-plane node and run:
kubeadm token create --print-join-command

#

Check the log of your user data script in:
/var/log/cloud-init.log and
/var/log/cloud-init-output.log
