# Ingress

The Ingress API is frozen, meaning it is no longer under active development and will not receive new features. Additionally, the Ingress controller used in this project, ingress-nginx, has been retired. However, since Ingress is still covered in the CKA exam, we'll use it for hands-on practice.

## Ingress controller and class

An `Ingress` resource on its own does nothing — it needs a controller watching it and an `IngressClass` linking the two together.

```shell
# The service that receives external traffic and routes it to backend services, per the Ingress rules
kubectl get service ingress-nginx-controller -n ingress-nginx
```

Note that this is a `LoadBalancer` service, and since this project has no cloud controller manager the external IP stays `<pending>` forever.

But `LoadBalancer` services are built on top of `NodePort`, so we can still reach the controller directly through any node's public IP on that `NodePort`.

```shell
# We'll use this to reach the ingress-nginx-controller service
worker_public_ip="$(terraform output -json worker_public_ips | jq -r 'first')"
node_port="$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.spec.ports[0].nodePort}')"
```

```shell
# IngressClass links Ingress resources to the controller that should implement them
kubectl get ingressclass nginx
```

Deploy the application that will serve as the backend for the Ingresses we'll create in the following steps:

```shell
# Create a pod and a service exposing it
kubectl run app8 --image=httpd --expose --port=80
```

## Basic ingress (no host, root path)

Without a `host` in the rule, the ingress matches any request regardless of the `Host` header — including requests made straight to a node's public IP.

```shell
# Create an ingress routing "/" to the app8 service
kubectl create ingress basic --class=nginx --rule="/=app8:80"

# No host defined, so this reaches the ingress via the worker's public IP
curl http://$worker_public_ip:$node_port
```

## Path-based routing (with exact path)

A rule can also match on a specific path instead of just `/`.

```shell
# Create an ingress routing "/hello" to the same app8 service
kubectl create ingress hello --class=nginx --rule="/hello=app8:80"

# The ingress forwards the original request path to the backend unchanged, unless told otherwise
# httpd only serves a document at `/`, so if it gets a request for `/hello` it will find nothing there and return 404
# The fix is the `nginx.ingress.kubernetes.io/rewrite-target` annotation, which rewrites the path before it's sent to the backend
# Note that this is an ingress-nginx implementation-specific feature, not defined in the Kubernetes Ingress API
kubectl annotate ingress hello nginx.ingress.kubernetes.io/rewrite-target=/

curl http://$worker_public_ip:$node_port/hello
```

## Path-based routing (with path prefix)

```shell
# Create an ingress with `Prefix` path type instead of `Exact`
kubectl create ingress hello-slash-star --class=nginx --rule='/hello/*=app8:80'

kubectl annotate ingress hello-slash-star nginx.ingress.kubernetes.io/rewrite-target=/

curl http://$worker_public_ip:$node_port/hello/world
```

## Host-based routing

```shell
kubectl create ingress example --class=nginx --rule='example.com/=app8:80'
curl -H "Host: example.com" http://$worker_public_ip:$node_port
```

## Try it yourself

- Add a second path (e.g. `/v2=app8:80` on a new service) to the same `hello` ingress and see how nginx picks between overlapping rules.
- Recreate the `hello` rule with a trailing `*` (e.g. `/hello*=app8:80`) — check the resulting `pathType` and whether `/hello/anything` now matches.
- Set a `host` on a rule (`--rule="foo.com/=app8:80"`) and try curling with `-H "Host: foo.com"` vs without it.
- Look at what `nginx.ingress.kubernetes.io/rewrite-target: /$2` combined with a capture-group path (`/hello(/|$)(.*)`) does differently from a plain `/`.
- Delete the `IngressClass` (or point the ingress at a class that doesn't exist) and see how the controller and `kubectl get ingress` reflect that.
