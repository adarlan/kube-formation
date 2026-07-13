# app1

## Create deployment

```shell
cat <<EOF | kubectl create -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: app1
  name: app1
spec:
  selector:
    matchLabels:
      app: app1
  template:
    metadata:
      labels:
        app: app1
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
      - name: busybox
        image: busybox
        command:
        - sleep
        - infinity
EOF
```

## View

```
kubectl get all -l app=app1 -owide
kubectl get deployment app1 -owide
kubectl describe deployment app1
kubectl get pods -l app=app1 -owide
```

## Scale out

kubectl scale deployment app1 --replicas=3

## Expose

kubectl expose deployment app1 --port=80 --target-port=80

kubectl describe service app1

kubectl port-forward svc/app1 8080:80

curl http://localhost:8080

## Logs

Follow nginx logs across all replicas:

kubectl logs --selector app=app1 --container nginx --follow
