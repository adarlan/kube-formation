#!/bin/bash
set -e
cd $(dirname $0)

# Create Kubernetes node image
(
    cd packer

    set -ex
    packer init .
    packer build node-image.pkr.hcl
)

# Create SSH key pair
# The public key will be used by Terraform to add to the instances
# The private key will be used by Ansible to initialize the cluster
if [ ! -d ~/.ssh ]; then
    mkdir ~/.ssh
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
    cp ~/.ssh/id_rsa.pub ./terraform/
fi

# Create Kubernetes nodes
(
    cd terraform

    set -ex
    terraform apply
)

# TODO wait instances initialize?

control_plane_ip=$(terraform -chdir=./terraform output -raw control_plane_ip)
worker_1_ip=$(terraform -chdir=./terraform output -raw worker_1_ip)
worker_2_ip=$(terraform -chdir=./terraform output -raw worker_2_ip)

# Create Ansible hosts file
cat <<EOF > ansible/hosts
[controlplane]
controlplane0 ansible_host=$control_plane_ip
[workers]
worker1 ansible_host=$worker_1_ip
worker2 ansible_host=$worker_2_ip
EOF

# Add SSH known hosts
rm ~/.ssh/known_hosts
touch ~/.ssh/known_hosts
ssh-keyscan $control_plane_ip >> ~/.ssh/known_hosts
ssh-keyscan $worker_1_ip >> ~/.ssh/known_hosts
ssh-keyscan $worker_2_ip >> ~/.ssh/known_hosts
chmod 644 ~/.ssh/known_hosts

# Initialize Kubernetes cluster
(
    cd ansible

    set -ex
    ansible-playbook -i hosts -u ubuntu playbook.yaml
)
