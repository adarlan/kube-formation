# Kube Formation

A project designed to practice and understand the [Kubernetes](https://kubernetes.io/) architecture by setting up a cluster using [Kubeadm](https://kubernetes.io/docs/reference/setup-tools/kubeadm/) on [Amazon EC2](https://aws.amazon.com/ec2/) instances.

Requirements:

- [AWS CLI](https://aws.amazon.com/cli/)
- [Packer](https://packer.io/)
- [Terraform](https://terraform.io/)
- [Ansible](https://ansible.com/)

## Getting Started

Follow the steps below to set up the Kubernetes cluster.

Once you've finished exploring with your cluster, clean up resources by deprovisioning the cluster infrastructure.

### Clone the kube-formation repository

```shell
git clone https://github.com/adarlan/kube-formation.git
```

### Navigate to the kube-formation directory

```shell
cd kube-formation
```

### Build Kubernetes Node Image

Use Packer to create an AMI (Amazon Machine Image) for the cluster nodes:

```shell
./packer-build.sh
```

### Apply Kubernetes Infrastructure

Use Terraform to provision the cluster infrastructure:

```shell
./terraform-apply.sh
```

TODO wait instances initialize?

### Initialize Kubernetes Cluster

Use Ansible to initialize and join the cluster nodes:

```shell
./ansible-playbook.sh
```

### Shutdown

Destroy the cluster infrastructure:

```shell
./terraform-destroy.sh
```

Deregister AMI:

```shell
./ami-deregister.sh
```

Manually delete EBS snapshots created by CreateImage.
