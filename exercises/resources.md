## Create app2 namespace

kubectl create ns app2

kubectl config set-context --current -n app2

## Create resource quota for app2 namespace

kubectl create quota app2 --hard=cpu=1,memory=1G,resourcequotas=1

kubectl get quota
kubectl describe quota

## Create deployment

```
kubectl create deploy app2 --image=nginx
```

> The replicaset-controller will fail to create pods (`forbidden: failed quota: app2: must specify cpu for: nginx; memory for: nginx`)
> until we set resources.

## Set resources

Initially, QoS class is `BestEffort` (no requests or limits defined for any container).

Changing to `Burstable` (requests/limits set, but they are not equal):

```
kubectl set resources deployment app2 --requests=cpu=100m,memory=256Mi --limits=cpu=200m,memory=512Mi
```

To change QoS class to `Guaranteed`, set requests == limits for both CPU & memory.

## Scale

kubectl scale deploy app2 --replicas=2

## TODO

What if a pod consumption hit the limit? How to simulate this?
The quota ignores limit?
does it make sense to create multiple quotas in a namespace?
simulate pod eviction by reducing quota... use different qos and priority classes (maybe priority class in a different runbook?)
