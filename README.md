# Kube Formation

A project designed to practice and understand the [Kubernetes](https://kubernetes.io/) architecture by setting up a cluster on [Amazon EC2](https://aws.amazon.com/ec2/) instances.

Requirements:

- __AWS account__ - see [Sign up for AWS](https://portal.aws.amazon.com/billing/signup)
- __AWS CLI__ configured to access your AWS account - see [AWS CLI installation](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) and [AWS CLI configuration](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/configure/index.html)
- __Packer__ - see [Packer installation](https://developer.hashicorp.com/packer/install)
- __Terraform__ - see [Terraform installation](https://developer.hashicorp.com/terraform/install)
- __Ansible__ - see [Ansible installation](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)

Follow the steps below to set up your Kubernetes cluster. Once you've finished exploring with it, clean up resources by deprovisioning the cluster infrastructure.

### Build cluster node image

Use Packer to create an AMI (Amazon Machine Image) for the cluster nodes. The AMI will be based on Ubuntu and preconfigured with `containerd`, `kubeadm`, `kubelet` and `kubectl` to streamline cluster initialization.

```shell
./packer-build.sh
```

### Provision cluster infrastructure

Use Terraform to provision the cluster infrastructure, which includes three `t4g.small` instances (one control plane and two worker nodes) along with an SSH key pair and security groups configured to enable node communication, SSH access, and service connectivity.

```shell
./terraform-apply.sh
```

### Configure SSH

Prepare the private key, known hosts and Ansible inventory files. These will be used by Ansible to connect to the cluster nodes.

```shell
./ssh-config.sh
```

### Initialize cluster

Use Ansible to initialize and join the cluster nodes. Ansible will connect to the nodes and execute the `kubeadm init` command on the control plane node and the `kubeadm join` command on the worker nodes to complete the cluster setup.

```shell
./ansible-playbook.sh
```

### Shutdown

#### Deprovision cluster infrastructure

Use Terraform to destroy the cluster infrastructure. This will terminate the instances and remove the SSH key pair and security groups.

```shell
./terraform-destroy.sh
```

#### Deregister cluster node image

Use the AWS CLI to deregister any AMIs related to this project and delete the corresponding EBS snapshots.

```shell
./ami-deregister.sh
```
