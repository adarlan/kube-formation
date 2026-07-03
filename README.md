# Kube Formation

A project designed to practice and understand the [Kubernetes](https://kubernetes.io/) architecture by setting up a cluster on [Amazon EC2](https://aws.amazon.com/ec2/) instances. Terraform provisions the infrastructure and Ansible bootstraps the cluster.

The default topology is one control plane node and one worker node, both ARM64 `t4g.small` instances running Ubuntu 22.04. Instances auto-shutdown after 3 hours as a cost safeguard.

## Setup

```shell
make setup
```

This will:
1. Initialize and apply Terraform — provisions EC2 instances, EIPs, and security groups
2. Configure local SSH access — extracts the private key, scans known hosts, and generates the Ansible inventory
3. Prepare the nodes — installs containerd, kubeadm, kubelet, and kubectl on all nodes
4. Create the cluster — runs `kubeadm init` on the control plane, joins the worker nodes, and installs a CNI plugin
5. Configure kubectl — extracts credentials from the control plane and updates local kubeconfig

Verify the cluster is up:

```shell
kubectl get nodes
```

## Pause & Resume

Stop the instances when you are no longer using the cluster to avoid compute charges.

```shell
make stop
```

```shell
make start
```

Elastic IPs keep node addresses stable across stop/start, so the cluster comes back up on its own.

> Note: After you stop the instances, you are no longer charged usage or data transfer fees for it.
> However, you will still be billed for associated Elastic IP addresses and EBS volumes.

## Connecting to nodes

SSH into a node directly:

```shell
make ssh-into NODE=controlplane1
make ssh-into NODE=worker1
```

## Deploy a sample app

`manifest.yaml` deploys an nginx `Deployment` with 10 replicas and exposes it via a `NodePort` on port 30000:

```shell
kubectl apply -f manifest.yaml
```

Access it at `http://<worker-public-ip>:30000`.

## Destroy

```shell
make destroy
```

## Contributing

Contributions are welcome! Please submit a pull request or open an issue.
