# Kubeadm Lab

A project designed to practice and understand the [Kubernetes](https://kubernetes.io/) architecture by setting up a cluster on [Amazon EC2](https://aws.amazon.com/ec2/) instances using [Kubeadm](https://kubernetes.io/docs/reference/setup-tools/kubeadm/).

## Setup

```shell
make setup-cluster
```

This will:

1. 🏗️ Provision infrastructure – provisions EC2 instances, security groups, and SSH key pair
2. 🔑 Configure SSH – extracts the private key, and scans known hosts
3. 🛠️ Prepare hosts – loads kernel modules and parameters, and installs containerd, kubeadm, kubelet, and kubectl on all nodes
4. 🚀 Bootstrap cluster – initializes cluster on the control-plane, and join a worker node
5. ⚙️ Update kubeconfig – extracts admin credentials from the control-plane and updates local kubeconfig

Verify the cluster is up:

```shell
kubectl get nodes
```

## Deploy a sample app

Worker nodes accept inbound traffic on the NodePort range (30000-32767), so a `NodePort` service is
reachable at `http://<worker-public-ip>:<node-port>` once deployed, e.g.:

```shell
kubectl create deployment app1 --image=nginx --port=80
kubectl expose deployment app1 --type=NodePort --port=80 --target-port=80

node_port="$(kubectl get service app1 -o jsonpath='{.spec.ports[0].nodePort}')"
worker_public_ip="$(terraform -chdir=terraform output -json worker_public_ips | jq -r 'first')"

curl http://$worker_public_ip:$node_port
```

See more exercises in [`./exercises`](./exercises/).

## Resize the cluster

Initially, the cluster has a single control-plane node and a single worker node.

Add nodes:

```shell
make add-control-plane NAME=controlplane2
make add-worker NAME=worker2
```

Remove nodes:

```shell
make remove-node NAME=controlplane2
make remove-node NAME=worker2
```

## Connecting to hosts

SSH into a host directly:

```shell
make ssh-into-host NAME=controlplane1
make ssh-into-host NAME=worker1
```

## Destroy

```shell
make destroy-cluster
```

## Contributing

Contributions are welcome! Please submit a pull request or open an issue.
