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
ansible-playbook prepare-nodes.yml   # installs containerd + kubeadm/kubelet/kubectl on all nodes
ansible-playbook create-cluster.yml     # kubeadm init, joins workers, installs Flannel CNI, saves kubeconfig
kubectl get nodes
```

**Save money (stop/restart):** IPs change on restart, so re-run `ssh-config.sh` and `create-cluster.yml`.
```shell
./stop-instances.sh
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
  └─ Outputs: nodes, control_plane_nodes, worker_nodes (maps of name → {public_ip, instance_id})

ssh-config.sh
  └─ Reads private_key and node IPs from terraform outputs
  └─ Writes known_hosts via ssh-keyscan
  └─ Generates inventory.ini from control_plane_nodes and worker_nodes outputs

prepare-nodes.yml  →  hosts: k8s (all nodes)
  └─ Disables swap, loads overlay + br_netfilter, configures sysctl
  └─ Installs containerd.io from Docker repo; enables systemd cgroup driver
  └─ Installs kubeadm/kubelet/kubectl from pkgs.k8s.io (v1.36), holds versions

create-cluster.yml
  └─ bootstrap_control_plane: kubeadm init, Flannel CNI, saves kubeconfig locally
  └─ control_plane (additional): kubeadm join --control-plane (currently errors on second CP)
  └─ workers: kubeadm join
```

Generated files (all gitignored): `inventory.ini`, `private_key`, `known_hosts`, `kubeconfig`, `terraform.tfstate*`.

## Ignored directories

Skip any directory that contains a `.gitignore` file whose entire content is `*`. These directories are fully gitignored scratch/build areas not part of the project.
