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

Use Packer to create an AMI (Amazon Machine Image) for the cluster nodes:

```shell
./packer-build.sh
```

### Provision cluster infrastructure

Use Terraform to provision the cluster infrastructure:

```shell
./terraform-apply.sh
```

### Configure SSH

Prepare private key, known hosts and Ansible inventory files:

```shell
./ssh-config.sh
```

### Initialize cluster

Use Ansible to initialize and join the cluster nodes:

```shell
./ansible-playbook.sh
```

### Shutdown

Deprovision the cluster infrastructure:

```shell
./terraform-destroy.sh
```

Deregister the cluster node image:

```shell
./ami-deregister.sh
```
