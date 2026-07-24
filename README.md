# Kubeadm Lab

A project designed to practice and understand the [Kubernetes](https://kubernetes.io/) architecture by setting up a cluster on [Amazon EC2](https://aws.amazon.com/ec2/) instances using [Kubeadm](https://kubernetes.io/docs/reference/setup-tools/kubeadm/).

## 📋 Requirements

- An AWS account, with credentials configured for the [AWS CLI](https://aws.amazon.com/cli/)
- [Terraform](https://developer.hashicorp.com/terraform)
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)
- [jq](https://jqlang.org/) and [yq](https://github.com/mikefarah/yq)
- `make` and an SSH client (with `ssh-keyscan`)

## 🏗️ Setup cluster

```shell
make setup
```

This will:

1. Provision infrastructure – create the EC2 instances, security groups and key pair; scan host keys
2. Prepare nodes – configure the kernel and install kubeadm-required packages on `controlplane1` and `worker1`
3. Initialize control-plane – run `kubeadm init` on `controlplane1`
4. Update kubeconfig – pull admin credentials and merge them into the local kubeconfig
5. Install addons – CNI plugin, metrics-server and ingress controller
6. Join worker – join `worker1` to the cluster

Verify the cluster is up:

```shell
kubectl get nodes
```

## 🚀 Deploy a sample app

Worker nodes accept inbound traffic on the NodePort range (30000-32767), so a `NodePort` service is
reachable at `http://<worker-public-ip>:<node-port>` once deployed, e.g.:

```shell
kubectl create deployment app1 --image=nginx
kubectl expose deployment app1 --type=NodePort --port=80

node_port="$(kubectl get service app1 -o jsonpath='{.spec.ports[0].nodePort}')"
worker_public_ip="$(terraform output -json worker_public_ips | jq -r 'first')"

curl http://$worker_public_ip:$node_port
```

## 📡 SSH into hosts

SSH into hosts for troubleshooting.

```shell
make ssh-into NAME=controlplane1
```

## 📈 Add nodes

Provision new instances and join them as nodes into the cluster.

```shell
make add-worker NAME=worker2
```

```shell
make add-control-plane NAME=controlplane2
```

## 📉 Remove nodes

Gracefuly remove nodes from the cluster and terminate their corresponding instances.

```shell
make remove-node NAME=controlplane2
```

## 💀 Simulate node crash

Terminate the instance without properly removing its node from the cluster.
The node becomes `NotReady` after missing heartbeats.

```shell
make destroy-instance NAME=worker1
```

## 💥 Destroy cluster

```shell
make destroy
```

## ⚠️ Limitations

This project favors simplicity and low cost over production-readiness.

Known limitations:

- **No load balancer in front of the control plane.** For simplicity, the cluster uses `controlplane1`'s public IP as its control-plane endpoint. Since this address is embedded in the API server certificate and every node's kubeconfig, `controlplane1` cannot be removed or terminated without breaking access to the cluster, even if other control-plane nodes are still running.

- **No cloud controller manager.** Since the cluster is not integrated with AWS, Kubernetes cannot provision cloud load balancers. Consequently, `Service` objects of type `LoadBalancer` remain in the pending state indefinitely. To expose workloads externally, use NodePort and connect directly to a node's public IP.

- **Minimal networking.** Everything runs in the AWS account's default VPC/subnets. There's no custom VPC, no private subnets, no NAT gateway. Security groups allow inbound access from any source to SSH (22) on all nodes, the API server (6443) on control-plane nodes, and the NodePort range (30000-32767) on worker nodes, which is convenient for a lab but far more permissive than you'd want in production.

## 🤝 Contributing

Contributions are welcome! Please submit a pull request or open an issue.
