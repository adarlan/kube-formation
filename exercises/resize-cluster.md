
Initially, our cluster has 1 worker node.

```shell
kubectl get nodes
```

Everything we deploy will be scheduled in `worker1`:

```shell
# Create deployment
kubectl create deployment app6 --image=nginx --port=80 --replicas=10

# All pods running in worker1
kubectl get pods -l app=app6 -owide
```

Expose deployment:

```shell
kubectl expose deployment app6 --port=80 --target-port=80

# Access the app
kubectl run curl --image=curlimages/curl -it --rm -- curl http://app6
```

Resize the cluster to have 2 worker nodes:

```shell
# Resize cluster
make setup W=2

# View nodes
kubectl get nodes

# Pods still running in worker1
kubectl get pods -l app=app6 -owide

# No pods running in worker2 yet
kubectl get pods -l app=app6 --field-selector spec.nodeName=worker2
```

Scale deployment:

```shell
kubectl scale deployment app6 --replicas=20

# Now we have pods running on both nodes
kubectl get pods -l app=app6 -owide
```

What if a node crashes suddenly?

```shell
# Stop worker2 EC2 instance to simulate a node crash
make stop NODE=worker2

# After missing heartbeats for a while, the Node Controller marks worker2 as "NotReady"
kubectl get node worker2

# But pods in worker2 still look like "Running"
# Because the API server cannot ask the kubelet: "Hey, is this container still running?"
# The kubelet is gone. So the last known state remains: "Running"
kubectl get pods -l app=app6 -owide

# The service keeps working.
# The EndpointSlice controller notices: These Pods belong to a NotReady node.
# It marks their endpoints as not ready.
# So the Service stops routing traffic there.
# Clients only receive endpoints from worker1.
kubectl run curl --image=curlimages/curl -it --rm -- curl http://app6

# Kubernetes waits about 5 minutes before deciding: This node is probably gone.
# The Node Controller starts Pod eviction.
# It deletes the Pods that were assigned to worker2.

# Deployment notices missing replicas
# ReplicaSet creates replacements
# Scheduler places them on worker1

# Old Pods remain Terminating
# Kubelet is dead, so nobody ever confirms the deletion
# Eventually the Node Controller force-removes those Pods from the API.
```

Bring back `worker2` and restart `app6` to redistribute pods across both nodes:

```shell
make start NODE=worker2

kubectl rollout restart deployment app6 \
&& kubectl rollout status deployment app6

kubectl get pods -l app=app6 -owide
```

Intentionally remove a node:

```shell
# Mark node as unschedulable (optional)
kubectl cordon worker2 \
&& kubectl get node worker2

# View all pods running in the node
kubectl get pods -A --field-selector spec.nodeName=worker2

# Drain node
kubectl drain worker2 --ignore-daemonsets

# No more pods in the node, except for daemonset-managed pods
kubectl get pods -A --field-selector spec.nodeName=worker2

# Delete node
kubectl delete node worker2

make stop NODE=worker2
```

## Try it yourself

What happens to stand-alone pods when a node crashes?

## One is none, two is one

For etcd, the reality is:

Control planes (stacked etcd)	Can lose 1 node?
1	❌ No
2	❌ No
3	✅ Yes
4	✅ Yes
5	✅ Yes (can lose 2)

Notice something unintuitive: 4 nodes don't provide better fault tolerance than 3. They still require a quorum of 3, so they can only lose one node.

That's why etcd (and other Raft-based systems) strongly recommends an odd number of members.

1 control plane: no HA.
2 control planes (stacked etcd): still no HA against control plane failure.
3 control planes: first configuration that actually tolerates one control plane failure.

The reason is purely mathematical: quorum is ⌊N/2⌋ + 1.

For:

N = 2 → quorum = 2 (must have both)
N = 3 → quorum = 2 (can lose one)

This catches many people by surprise because "adding a second control plane" feels like it should add redundancy. It does add another API server instance, but because the control plane's persistent state is governed by etcd quorum, the cluster as a whole is still not resilient to the loss of either control plane.
