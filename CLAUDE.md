# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project does

Provisions a Kubernetes cluster on AWS EC2 using Terraform (infrastructure) and Ansible (cluster bootstrap). The default topology is one control plane node (`controlplane1`) and one worker node (`worker1`), both `t4g.small` ARM64 instances running Ubuntu 22.04. Instances auto-shutdown after 3 hours as a cost safeguard.

## Prerequisites

AWS CLI configured, Terraform, Ansible, kubectl, jq, and yq installed locally. AWS credentials must be set in the environment before running anything.

## Cluster lifecycle

**Bring up (single command):**
```shell
./setup.sh
```
This runs: `terraform init && terraform apply` → `ssh-config.sh` → `prepare-nodes.yml` → `create-cluster.yml` → `update-kubeconfig.sh`

**Bring up (step by step):**
```shell
terraform init
terraform apply         # provisions EC2 instances, generates inventory.ini
./ssh-config.sh         # extracts private key, scans known_hosts, generates inventory.ini, tests ping
ansible-playbook prepare-nodes.yml   # installs containerd + kubeadm/kubelet/kubectl on all nodes
ansible-playbook create-cluster.yml  # kubeadm init, joins workers, installs Flannel CNI
./update-kubeconfig.sh               # extracts creds from control plane, sets kubectl context kube-formation
kubectl get nodes
```

**Pause & resume:** EIPs keep IPs stable across stop/start, so the cluster persists on EBS and comes back up on its own.
```shell
./ec2-stop.sh
./ec2-start.sh
```

**Tear down:**
```shell
./destroy.sh
```

**SSH into a node:**
```shell
./ssh-into.sh controlplane1
./ssh-into.sh worker1
```

**Deploy a sample app:**
```shell
kubectl apply -f manifest.yaml   # nginx Deployment (10 replicas) + NodePort :30000
# Access at http://<worker-public-ip>:30000
```

## Architecture

```
infra.tf
  └─ EC2 instances (for_each over local.nodes map)
  └─ Security groups: node-firewall (all nodes), control-plane-firewall, worker-firewall
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
  └─ bootstrap_control_plane: kubeadm init, Flannel CNI, stores join_command + certificate_key as host facts
  └─ control_plane (additional): kubeadm join --control-plane using stored facts
  └─ workers: kubeadm join using stored join_command

update-kubeconfig.sh
  └─ SSHes into controlplane1, reads /etc/kubernetes/admin.conf
  └─ Extracts ca.crt, client.crt, client.key locally
  └─ Configures kubectl context named kube-formation pointing at controlplane1's public IP
```

Generated files (all gitignored): `inventory.ini`, `private_key`, `known_hosts`, `ca.crt`, `client.crt`, `client.key`, `terraform.tfstate*`.

## Ignored directories

Skip any directory that contains a `.gitignore` file whose entire content is `*`. These directories are fully gitignored scratch/build areas not part of the project.
