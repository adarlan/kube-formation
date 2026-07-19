# Kubeadm Lab

A project designed to practice and understand the [Kubernetes](https://kubernetes.io/) architecture by setting up a cluster on [Amazon EC2](https://aws.amazon.com/ec2/) instances using [Kubeadm](https://kubernetes.io/docs/reference/setup-tools/kubeadm/).

<!-- TODO requirements: aws account, aws cli, terraform, kubectl, make, jq, etc -->

## 🏗️ Setup cluster

```shell
make setup
```

This will:

1. Provision infrastructure – provision instances and security groups
2. Configure SSH – generate key pair and discover host keys
3. Prepare hosts – configure kernel and install Kubernetes packages
4. Bootstrap cluster – initialize control-plane and join a worker node
5. Update kubeconfig – pull admin credentials and update local kubeconfig

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

See [more examples](./exercises/).

## 📡 SSH into hosts

```shell
# SSH into hosts for troubleshooting
make ssh-into NAME=controlplane1
make ssh-into NAME=worker1
```

## 📈 Add nodes

```shell
# Provision new instances and join them into the cluster
make add-node NAME=controlplane2 ROLE=control-plane
make add-node NAME=worker2 ROLE=worker
make add-node NAME=worker3
```

## 📉 Remove nodes

```shell
# Gracefuly remove nodes from the cluster and terminate their instances
make remove-node NAME=controlplane2
make remove-node NAME=worker2
```

## 💀 Simulate node crash

```shell
# Kill a node without properly removing it from the cluster
make terminate-instance NAME=worker3
```

## 💥 Destroy cluster

```shell
# Destroy the cluster
make destroy
```

## 🤝 Contributing

Contributions are welcome! Please submit a pull request or open an issue.
