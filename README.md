# Kube Formation

A project designed to practice and understand the [Kubernetes](https://kubernetes.io/) architecture by setting up a cluster on [Amazon EC2](https://aws.amazon.com/ec2/) instances. This project leverages [Packer](https://www.packer.io/) to create images for the cluster nodes, [Terraform](https://www.terraform.io/) to provision the infrastructure, and [Ansible](https://ansible.com/) to initialize the cluster.

## Requirements

Ensure you have the following installed and configured before proceeding:

- __AWS account__ - see [Sign up for AWS](https://portal.aws.amazon.com/billing/signup)
- __AWS CLI__ configured to access your AWS account - see [AWS CLI installation guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) and [AWS CLI configuration guide](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/configure/index.html)
- __Packer__ - see [Packer installation guide](https://developer.hashicorp.com/packer/install)
- __Terraform__ - see [Terraform installation guide](https://developer.hashicorp.com/terraform/install)
- __Ansible__ - see [Ansible installation guide](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)

## Setup Instructions

Follow the steps below to set up your Kubernetes cluster. Once finished, you can clean up the resources by deprovisioning the cluster infrastructure.

### 1. Build Node Image

Use Packer to create an Amazon Machine Image (AMI) for the cluster nodes. The AMI is based on Ubuntu and preconfigured with essential Kubernetes components ([kubeadm](https://kubernetes.io/docs/reference/setup-tools/kubeadm/), [kubelet](https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/), [kubectl](https://kubernetes.io/docs/reference/kubectl/) and [containerd](https://containerd.io/)) to simplify cluster initialization.

```shell
./packer-build.sh
```

### 2. Provision Infrastructure

Use Terraform to provision the cluster infrastructure, including three EC2 instances (one control plane and two worker nodes) along with an SSH key pair and security groups configured to enable node communication, SSH access, and service connectivity.

```shell
./terraform-apply.sh
```

### 3. Configure SSH

Prepare the private key, known hosts and Ansible inventory files. These will be used by Ansible to connect to the cluster nodes.

```shell
./ssh-config.sh
```

### 4. Initialize Cluster

Use Ansible to initialize and join the cluster nodes. Ansible will connect to the nodes and execute the `kubeadm init` on the control plane and `kubeadm join` on the workers to complete the cluster setup.

```shell
./ansible-playbook.sh
```

## Shutdown & Cleanup

When finished, deprovision the cluster to avoid unnecessary costs.

### 1. Deprovision Infrastructure

Use Terraform to destroy the infrastructure, terminating instances and removing associated resources.

```shell
./terraform-destroy.sh
```

### 2. Deregister Node Image

Use the AWS CLI to deregister any AMIs created for this project and delete their associated EBS snapshots.

```shell
./ami-deregister.sh
```

## Contributing

Contributions are welcome! If you’d like to improve this project, please submit a pull request or open an issue.
