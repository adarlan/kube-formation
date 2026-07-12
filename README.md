# Kube Formation

A project designed to practice and understand the [Kubernetes](https://kubernetes.io/) architecture by setting up a cluster on [Amazon EC2](https://aws.amazon.com/ec2/) instances. Terraform provisions the infrastructure and Ansible initializes the cluster.

## Setup

```shell
make setup
```

This will:
1. Initialize and apply Terraform — provisions EC2 instances, EIPs, security groups, and SSH key pair
2. Configure SSH access — extracts the private key, scans known hosts, and generates the Ansible inventory
3. Create the cluster — runs `kubeadm init` on the control plane, joins the worker nodes, and installs a CNI plugin
4. Configure kubectl — extracts credentials from the control plane and updates local kubeconfig

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

Worker nodes accept inbound traffic on the NodePort range (30000-32767), so a `NodePort` service is
reachable at `http://<worker-public-ip>:<node-port>` once deployed, e.g.:

```shell
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --type=NodePort --port=80
```

> More exercises: [lab](./lab/)

## Destroy

```shell
make destroy
```

## Contributing

Contributions are welcome! Please submit a pull request or open an issue.
