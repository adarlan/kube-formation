# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project does

Provisions a Kubernetes cluster on AWS EC2 using Terraform (infrastructure) and Ansible (cluster bootstrap). The default topology is one control plane node (`controlplane1`) and one worker node (`worker1`), both `t4g.small` ARM64 instances running Ubuntu 22.04. Instances auto-shutdown after 3 hours as a cost safeguard.

## Prerequisites

AWS CLI configured, Terraform, Ansible, kubectl, and jq installed locally. AWS credentials and `KUBECONFIG` are set in `.env` (gitignored — copy and fill in before running anything).

## Cluster lifecycle

**Bring up:**
```shell
source .env
terraform init
terraform apply         # provisions EC2 instances, generates inventory.ini
./ssh-config.sh         # extracts private key, scans known_hosts, tests Ansible ping
ansible-playbook prepare-machines.yml   # installs containerd + kubeadm/kubelet/kubectl on all nodes
ansible-playbook create-cluster.yml     # kubeadm init, joins workers, installs Flannel CNI, saves kubeconfig
kubectl get nodes
```

**Save money (stop/restart):** IPs change on restart, so re-run `ssh-config.sh` and `create-cluster.yml`.
```shell
./stop-machines.sh
./resume.sh && ./ssh-config.sh && ansible-playbook create-cluster.yml
```

**Tear down:**
```shell
terraform destroy
```

**Deploy a sample app:**
```shell
kubectl apply -f manifest.yaml   # nginx Deployment (10 replicas) + NodePort :30000
```

## Architecture

```
infra.tf
  └─ EC2 instances (for_each over local.nodes map)
  └─ Security groups: node_firewall (all nodes), control_plane_firewall, worker_firewall
  └─ SSM IAM role (allows AWS Systems Manager access without bastion)
  └─ Generates inventory.ini via local_file resource

ssh-config.sh
  └─ Reads private_key and IPs from terraform output
  └─ Writes known_hosts via ssh-keyscan

prepare-machines.yml  →  hosts: k8s (all nodes)
  └─ Disables swap, loads overlay + br_netfilter, configures sysctl
  └─ Installs containerd.io from Docker repo; enables systemd cgroup driver
  └─ Installs kubeadm/kubelet/kubectl from pkgs.k8s.io (v1.36), holds versions

create-cluster.yml
  └─ bootstrap_control_plane: kubeadm init, Flannel CNI, saves kubeconfig locally
  └─ control_plane (additional): kubeadm join --control-plane (currently errors on second CP)
  └─ workers: kubeadm join
```

Generated files (all gitignored): `inventory.ini`, `private_key`, `known_hosts`, `kubeconfig`, `terraform.tfstate*`.

## AMI (optional, currently inactive)

`ami/` contains a Packer build (`main.pkr.hcl` + `provisioner-script.sh`) that bakes a custom AMI with containerd and Kubernetes tools pre-installed. The main flow above skips this and uses stock Ubuntu, running `prepare-machines.yml` instead. The `up.sh` script at the root is an older all-in-one script that references the Packer build — it is not the current workflow.

## Troubleshooting

```shell
sudo journalctl -u kubelet   # run on a node via SSH to debug kubelet issues
```
