# pod1

## Run nginx Pod

kubectl run pod1 --image=nginx --port=80
kubectl get pod pod1
kubectl describe pod pod1

## TODO Logs

## Access from host

kubectl port-forward pod/pod1 8080:80

curl http://localhost:8080

## Access from another pod

kubectl get pod pod1 -o jsonpath='{.status.podIP}'
kubectl run bb --image=busybox -it --rm -- sh

wget -qO- http://<IP>

## Expose with ClusterIP service

kubectl expose pod/pod1 --port=80 --target-port=80
kubectl get service pod1
kubectl describe service pod1
kubectl port-forward svc/pod1 8080:80

curl http://localhost:8080

# pod2

Create pod and service in a single command:

```
kubectl run pod2 --image=nginx --port=80 --expose=true
```

# pod3

```
kubectl run pod3 --image=busybox:1.37 -- sleep infinity
```

Let's update the container image.

> The pod will be restarted.

## Update with `kubectl set`

```
kubectl set image pod/pod3 pod3=busybox:1.38
```

## Update with `kubectl patch`

```
kubectl patch pod/pod3 -p '{"spec":{"containers":[{"name":"pod3","image":"busybox:1.38"}]}}'
```

## Update with `kubectl edit`

```
kubectl edit pod/pod3
```
