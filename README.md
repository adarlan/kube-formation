# Kube Formation

A project designed to practice and understand the [Kubernetes](https://kubernetes.io/) architecture by setting up a cluster using [Kubeadm](https://kubernetes.io/docs/reference/setup-tools/kubeadm/). This project leverages [Amazon EC2](https://aws.amazon.com/ec2/) for Infrastructure-as-a-Service, [Packer](https://packer.io/) to create images for the cluster nodes, [Terraform](https://terraform.io/) to provision the cluster infrastructure, [Ansible](https://ansible.com/) to initialize and join the cluster nodes, and other tools.

## Getting Started

Follow the steps below to set up a Kubernetes cluster on Amazon EC2.

Once you've finished exploring with your cluster, clean up resources by deprovisioning the cluster infrastructure.

### Clone the kube-formation repository

```shell
git clone https://github.com/adarlan/kube-formation.git
```

### Navigate to the kube-formation directory

```shell
cd kube-formation
```

### Configure secrets

Create the `secrets` directory and add some files there:

```shell
mkdir -p secrets

echo && read -p "AWS account ID: " aws_account_id
read -p "AWS access key ID: " aws_access_key_id
read -sp "AWS secret access key: " aws_secret_access_key && echo
read -p "AWS region: " aws_region

echo $aws_account_id > secrets/aws_account_id
echo $aws_access_key_id > secrets/aws_access_key_id
echo $aws_secret_access_key > secrets/aws_secret_access_key
echo $aws_region > secrets/aws_region
```

If you have the AWS CLI installed and configured, you can create these files by executing the following commands:

```shell
mkdir -p secrets

echo && read -p "AWS CLI profile: " aws_profile
read -p "AWS region: " aws_region

aws --profile=$aws_profile sts get-caller-identity --query "Account" --output text > secrets/aws_account_id
aws --profile=$aws_profile configure get aws_access_key_id > secrets/aws_access_key_id
aws --profile=$aws_profile configure get aws_secret_access_key > secrets/aws_secret_access_key
echo $aws_region > secrets/aws_region
```

### Build Kubernetes Node AMI

```shell
./packer/docker-run.sh ./build-kubernetes-node-ami.sh
```

### Generate SSH Key Pair

The public key will be used by Terraform to add to the instances.
The private key will be used by Ansible to initialize the cluster.

```shell
./ssh-client/docker-run.sh ./generate-ssh-key-pair.sh
```

### Apply Kubernetes Infrastructure

```shell
./terraform/docker-run.sh ./apply-kubernetes-infrastructure.sh
```

<!-- TODO wait instances initialize? -->

### Initialize Kubernetes Cluster

```shell
./ansible/docker-run.sh ./initialize-kubernetes-cluster.sh
```

### Shutdown

```shell
./terraform/docker-run.sh ./destroy-kubernetes-infrastructure.sh
./aws-cli/docker-run.sh ./deregister-kubernetes-node-ami.sh
# TODO delete EBS snapshots created by CreateImage (Standard EBS Snapshot Storage Pricing: $0.05/GB-month)
# TODO aws_nuke
```
