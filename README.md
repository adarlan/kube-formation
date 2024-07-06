# Kube Formation

This project is designed to help you practice and understand the Kubernetes architecture by setting up a cluster using kubeadm on Amazon EC2 instances. The project leverages the following tools:

- Packer: For creating immutable AMIs for the cluster nodes.
- Terraform: For provisioning the EC2 instances and other resources as infrastructure-as-code.
- Ansible: For initializing and configuring the Kubernetes cluster.
- AWS CLI: ...
- AWS Nuke: ...
- SSH Client: ...

## Secrets

```shell
aws_profile=default
aws_region=us-east-1
mkdir -p secrets

# aws_account_id
aws --profile=$aws_profile sts get-caller-identity --query "Account" --output text > secrets/aws_account_id

# aws_access_key_id
aws --profile=$aws_profile configure get aws_access_key_id > secrets/aws_access_key_id

# aws_secret_access_key
aws --profile=$aws_profile configure get aws_secret_access_key > secrets/aws_secret_access_key

# aws_region
echo $aws_region > secrets/aws_region
```

## Setup

```shell
# Packer: Build Kubernetes Node AMI
./packer/docker-run.sh ./build-kubernetes-node-ami.sh

# SSH Client: Generate SSH Key Pair
# The public key will be used by Terraform to add to the instances
# The private key will be used by Ansible to initialize the cluster
./ssh-client/docker-run.sh ./generate-ssh-key-pair.sh

# Terraform: Apply Kubernetes Infrastructure
./terraform/docker-run.sh ./apply-kubernetes-infrastructure.sh

# TODO wait instances initialize?

# Ansible: Initialize Kubernetes Cluster
./ansible/docker-run.sh ./initialize-kubernetes-cluster.sh
```

## Shutdown

```shell
./terraform/docker-run.sh ./destroy-kubernetes-infrastructure.sh
./aws-cli/docker-run.sh ./deregister-kubernetes-node-ami.sh
# TODO delete EBS snapshots created by CreateImage (Standard EBS Snapshot Storage Pricing: $0.05/GB-month)
# TODO aws_nuke
```
