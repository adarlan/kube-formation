# Service types

Notes on the Kubernetes `Service` types.

## ClusterIP service

Default type. Exposes the pod only inside the cluster, on a stable virtual IP.

```shell
# Create a pod and expose it as a ClusterIP service (the default type)
kubectl run foo --image=nginx
kubectl expose pod foo --port=80

# Reach it from inside the cluster via the service name (DNS)
kubectl run client --image=curlimages/curl --restart=Never -- sleep infinity
kubectl exec client -- curl http://foo

kubectl delete svc foo
kubectl delete pod foo
```

## NodePort service

Opens the same port on every node's IP and forwards it to the service, on top of a ClusterIP. Useful for reaching the cluster from outside without a load balancer.

```shell
# Create a deployment and expose it as a NodePort service
kubectl create deployment app1 --image=nginx --port=80
kubectl expose deployment app1 --type=NodePort --port=80 --target-port=80

# NodePort is allocated from the cluster's node port range (default 30000-32767)
node_port="$(kubectl get service app1 -o jsonpath='{.spec.ports[0].nodePort}')"
worker_public_ip="$(terraform output -json worker_public_ips | jq -r 'first')"

# Reach it from outside the cluster via any node's IP + the node port
curl http://$worker_public_ip:$node_port

kubectl delete svc app1
kubectl delete deploy app1
```

## LoadBalancer service

Builds on top of NodePort and asks the cloud provider to provision an external load balancer that targets the nodes.

```shell
# Create a deployment and a LoadBalancer service
kubectl create deployment gong --image=nginx --port=80
kubectl create service loadbalancer gong --tcp=80:80

# The service is accessible internally, same as a ClusterIP service
kubectl run client --image=curlimages/curl --restart=Never -- sleep infinity
kubectl exec client -- curl http://gong

# In our kubeadm-lab cluster there is no cloud controller manager to provision a load balancer
# The EXTERNAL-IP will remain stuck in <pending> forever
kubectl get service gong

kubectl delete pod client
kubectl delete svc gong
kubectl delete deploy gong
```

## ExternalName service

No selector, no proxying: it's a DNS CNAME record so in-cluster clients can reach an external service by a cluster-local name.

```shell
# Create an ExternalName service pointing to an external domain
kubectl create service externalname httpbin --external-name=httpbin.org

# Resolves to a CNAME for httpbin.org, no cluster IP is allocated
kubectl run client --image=curlimages/curl --restart=Never -- sleep infinity
kubectl exec client -- curl http://httpbin/get

kubectl delete pod client
kubectl delete svc httpbin
```

## Headless service

A ClusterIP service with `clusterIP: None` — no virtual IP, no load-balancing. DNS returns the pod IPs directly.
Paired with a StatefulSet, it also gives every pod a stable, individual DNS hostname: `<pod-name>.<service-name>.<namespace>.svc.cluster.local`.

```shell
# Create a headless service (a ClusterIP service with clusterIP set to `None`)
kubectl create service clusterip appx --clusterip=None --tcp=80:80

# Create a StatefulSet governed by the service (serviceName must match it)
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: appx
spec:
  serviceName: appx
  selector:
    matchLabels:
      app: appx
  replicas: 3
  template:
    metadata:
      labels:
        app: appx
    spec:
      containers:
      - name: whoami
        image: traefik/whoami
EOF

kubectl run client --image=curlimages/curl --restart=Never -- sleep infinity

# Access each pod using the predictable DNS hostname
kubectl exec client -- curl http://appx-0.appx
kubectl exec client -- curl http://appx-1.appx
kubectl exec client -- curl http://appx-2.appx

kubectl delete pod client
kubectl delete sts appx
kubectl delete svc appx
```

## Try it yourself

- Inspect `kubectl get endpointslices` for each service type above — how do they differ, and which type has none?
- What if a pod backing a service isn't Ready yet — does it show up in the endpoints?
- Scale a deployment behind a ClusterIP service and watch the endpoints update. What load-balancing algorithm is used across pods?
- Create a service with no selector and manually manage its `Endpoints`/`EndpointSlice` — what's that useful for?
- Expose a service with more than one port (`--tcp=80:80,443:443` style) and see how `spec.ports[].name` becomes required.
- What if `targetPort` doesn't match any container port on the pod? What happens to `curl`?
- Compare `externalTrafficPolicy: Cluster` vs `Local` on the NodePort service — what changes for the client's source IP?
- Set `sessionAffinity: ClientIP` on a service and confirm repeated requests land on the same pod.
- Query DNS directly (`nslookup`/`dig` from the client pod) instead of curling — what SRV records exist for a headless service?
