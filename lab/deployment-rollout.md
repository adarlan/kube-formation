Let's explore with `kubectl rollout`.

This command is used to manage the rollout of deployments, daemonsets, and statefulsets,
but here we will try with deployments only.

Initial deployment:

```shell
# Create a deployment with nginx:1.30
kubectl create deployment app5 --image=nginx:1.30

# Annotate change cause (for a improved rollout history)
kubectl annotate deployment app5 kubernetes.io/change-cause="Initial deployment"

# View deployment, replicaset, and pod
kubectl get deployment app5 -owide
kubectl get replicasets -l app=app5 -owide
kubectl get pods -l app=app5 -owide

# View rollout history (only 1 revision for now)
kubectl rollout history deployment app5
```

Upgrade nginx to 1.31:

```shell
# Set image to nginx:1.31
kubectl set image deployment app5 nginx=nginx:1.31

# Annotate change cause
kubectl annotate deployment app5 kubernetes.io/change-cause="Upgrade nginx to 1.31"

# View rollout status (successfully rolled out)
kubectl rollout status deployment app5

# View rollout history
kubectl rollout history deployment app5

# View deployment, replicasets, and pods (everything's fine)
# The deployment creates a new replicaset, scaling it up while scaling down the previous replicaset to gradually replace the pods
kubectl get deployment app5 -owide
kubectl get replicasets -l app=app5 -owide
kubectl get pods -l app=app5 -owide
```

Everything is going well so far, so let's introduce a bit of chaos:

```shell
# Update container command (using a command that will crash the container)
kubectl patch deployment app5 -p '{
    "spec": {
        "template": {
            "spec": {
                "containers": [{
                    "name": "nginx",
                    "command": ["exit", "1"]
                }]
            }
        }
    }
}'

# Annotate change cause
kubectl annotate deployment app5 kubernetes.io/change-cause="Update command"

# View rollout status
# Waiting for deployment "app5" rollout to finish: 1 old replicas are pending termination...
# error: deployment "app5" exceeded its progress deadline
kubectl rollout status deployment app5

# View deployment, replicasets, and pods
# The pod associated with the new replicaset is in a crash loop
# The application didn't break because the pod associated with the previous replicaset is still running
kubectl get deployment app5 -owide
kubectl get replicasets -l app=app5 -owide
kubectl get pods -l app=app5 -owide
```

The rollout failed, but it wasn't a disaster since the app is still working.

Let's roll back to the previous revision:

```shell
# View rollout history
kubectl rollout history deployment app5

# View revision 2 details
kubectl rollout history deployment app5 --revision=2

# Roll back to revision 2
kubectl rollout undo deployment app5 --to-revision=2

# View roll back status (successfully rolled out)
kubectl rollout status deployment app5

# View deployment, replicasets, pods, and rollout history (everything's fine)
kubectl get deployment app5 -owide
kubectl get replicasets -l app=app5 -owide
kubectl get pods -l app=app5 -owide
kubectl rollout history deployment app5
```
