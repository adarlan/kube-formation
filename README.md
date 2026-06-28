# Kube Formation

A project designed to practice and understand the [Kubernetes](https://kubernetes.io/) architecture by setting up a cluster on [Amazon EC2](https://aws.amazon.com/ec2/) instances. Terraform provisions the infrastructure and Ansible bootstraps the cluster.

The default topology is one control plane node and one worker node, both ARM64 `t4g.small` instances running Ubuntu 22.04. Instances auto-shutdown after 3 hours as a cost safeguard.

## Requirements

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [Terraform](https://developer.hashicorp.com/terraform/install)
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [jq](https://jqlang.org/download/)

<!-- ## Configure AWS credentials

Copy `.env` and fill in your credentials:

```shell
cp .env .env.local  # or edit .env directly (it is gitignored)
```

```shell
export KUBECONFIG="kubeconfig"
export AWS_REGION="us-east-1"
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
```

Then source it before running any command:

```shell
source .env
``` -->

## Setup

```shell
./setup.sh
```

This will:
1. Initialize and apply Terraform — provisions EC2 instances, security groups, and an SSH key pair
2. Configure local SSH access — extracts the private key, scans known hosts, and generates the Ansible inventory
3. Prepare the nodes — installs containerd, kubeadm, kubelet, and kubectl on all nodes
4. Create the cluster — runs `kubeadm init` on the control plane, joins the worker nodes, installs the Flannel CNI plugin, and saves the kubeconfig locally

Verify the cluster is up:

```shell
kubectl get nodes
```

## Pause & Resume

Stop the instances when you are no longer using the cluster to avoid compute charges. Note that EBS volumes are still charged while instances are stopped.

```shell
./pause.sh
```

```shell
./resume.sh
```

When resuming, the instances receive new public IPs, so the cluster is reset and recreated automatically.

## Connecting to nodes

SSH into a node directly:

```shell
./ssh-into.sh controlplane1
./ssh-into.sh worker1
```

Or connect via [AWS Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html) (no open SSH port required — requires the [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)):

```shell
./ssm-into.sh controlplane1
./ssm-into.sh worker1
```

## Deploy a sample app

`manifest.yaml` deploys an nginx `Deployment` with 10 replicas and exposes it via a `NodePort` on port 30000:

```shell
kubectl apply -f manifest.yaml
```

Access it at `http://<worker-public-ip>:30000`.

## Destroy

```shell
./destroy.sh
```

<!-- ## Troubleshooting

Debug kubelet issues on a node:

```shell
sudo journalctl -u kubelet
``` -->

## Contributing

Contributions are welcome! Please submit a pull request or open an issue.
