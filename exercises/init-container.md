# Init Containers

```shell
# Create a pod that serves an app with nginx,
# with an init container to generate the html that will be served by the app
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: app9
  labels:
    app: app9
spec:
  containers:
  - name: app9
    image: nginx
    ports:
    - containerPort: 80
    volumeMounts:
    - name: html
      mountPath: /usr/share/nginx/html
  initContainers:
  - name: init
    image: busybox
    volumeMounts:
    - name: html
      mountPath: /usr/share/nginx/html
    command:
    - sh
    - -c
    - echo "<h1>Looks like it works</h1>" > /usr/share/nginx/html/index.html
  volumes:
  - name: html
    emptyDir: {}
EOF
# pod/app9 created

# Watch the pod go through the init phase before the main container starts
kubectl get pod app9 -w
# NAME   READY   STATUS            RESTARTS   AGE
# app9   0/1     Init:0/1          0          1s
# app9   0/1     PodInitializing   0          2s
# app9   1/1     Running           0          6s

# Expose the pod via a ClusterIP service so it can be reached by name
kubectl expose pod app9 --port=80 
# Run a throwaway pod to curl the service and confirm the init container's file is being served
kubectl run curl --image=curlimages/curl -it --rm -- curl http://app9
# <h1>Looks like it works</h1>
```

## Try it yourself

- Add a second init container and see them run in sequence, not parallel.
- Make the init container fail (non-zero exit) and watch the pod get stuck in `Init:Error` / `Init:CrashLoopBackOff`.
- Switch the shared volume from `emptyDir` to a `hostPath` and check what changes about where the data lives.
- Use `kubectl describe pod app9` while it's in `Init:0/1` to see how init container status is reported differently from regular containers.
