# kubectl CRUD

## Create resources imperatively

Imperative commands create objects directly from CLI flags — fast for one-offs, but limited in what they can configure.

```shell
# Create a pod
kubectl run ...

# Create other resources
kubectl create clusterrole ...
kubectl create clusterrolebinding ...
kubectl create configmap ...
kubectl create cronjob ...
kubectl create deployment ...
kubectl create ingress ...
kubectl create job ...
kubectl create namespace ...
kubectl create poddisruptionbudget ...
kubectl create priorityclass ...
kubectl create quota ...
kubectl create role ...
kubectl create rolebinding ...
kubectl create secret ...
kubectl create service ...
kubectl create serviceaccount ...
kubectl create token ...

# Create a service to expose an existing pod, deployment, replicaset, etc
kubectl expose ...

# Create an horizontal pod autoscaler for an existing deployment, replica set, stateful set, etc
kubectl autoscale ...
```

## Create resources declaratively

Declarative commands read full object definitions from manifests, so they can express anything the API supports.

```shell
# Create resources from manifest (file, directory, URL, stdin)
kubectl create -f ...
kubectl apply -f ...

# Create resources from kustomization
kubectl create -k ...
kubectl apply -k ...
```

## Manifest generation

Use `--dry-run=client -oyaml` to generate a YAML manifest instead of actually creating the resource.

For example:

```shell
# First, create the manifest file
kubectl create deployment foo --image=nginx --dry-run=client -oyaml > manifest.yaml

# Then, apply the manifest
kubectl apply -f manifest.yaml
```

## Read resources

Inspect what's running in the cluster and filter/format the output.

```shell
# Display one or many resources
kubectl get ...

# Get all resources, but not exactly all — "all" is a fixed set of built-in types, CRDs excluded
kubectl get all ...

# Common options
-A                    # All namespaces
-n foo                # Specific namespace
-l foo=bar            # Filter by label
-l foo!=bar           # Filter by label
--field-selector ...  # Filter by field
-o wide               # Additional columns
-o yaml               # YAML output
-o json               # JSON output
-o name               # Names only
-o jsonpath ...       # ...
--show-labels         # Display labels as a column
--sort-by             # Sort resources by a field (e.g. .metadata.creationTimestamp)
--watch               # Watch for changes

# Show details of a specific resource or group of resources
kubectl describe ...
```

## Update resources

Modify existing objects in place, either generically or via convenience commands for common changes.

```shell
# Generic update mechanisms
kubectl apply ...
kubectl replace ...
kubectl patch ...
kubectl edit ...

# Convenience commands for common updates
kubectl set env ...             # Update environment variables on a pod template
kubectl set image ...           # Update the image of a pod template
kubectl set resources ...       # Update resource requests/limits on objects with pod templates
kubectl set selector ...        # Set the selector on a resource
kubectl set serviceaccount ...  # Update the service account of a resource
kubectl set subject ...         # Update the user, group, or service account in a role binding or cluster role binding

# Just a few more (the list is extensive)
kubectl label ...
kubectl scale ...
kubectl annotate ...
```

## Combining imperative and declarative commands

`run`, `create`, `expose` and `autoscale` can't configure every field on the resources they create.

Pipe their `--dry-run=client -oyaml` output into `patch`, `set`, `label` or `annotate` (with `-f - --local`) to fill in the missing fields, then pipe the result into `apply` or `create`.

General pattern: generate, transform, then persist:

```
kubectl [run|create|expose|autoscale] [...] --dry-run=client -oyaml \
| kubectl [patch|set|label|annotate] [...] -f - --local -oyaml \
| kubectl [apply|create] -f -
```

Example: `kubectl create service` doesn't support a custom selector, so pipe it into `set selector`:

```shell
kubectl create service clusterip my-svc --tcp=80 --dry-run=client -oyaml \
| kubectl set selector app=my-app -f - --local -oyaml \
| kubectl apply -f -
```

## Delete resources

Remove objects from the cluster.

```shell
# Delete by name, label selector, manifest file, or resource type
kubectl delete ...
```

## Server-Side Apply vs. Client-Side Apply

Both send requests to the API server — `--server-side` only decides where the merge logic runs:

- Client-side apply (`--server-side=false`): kubectl fetches the live object, computes the patch locally, and sends the patch to the API server.

- Server-side apply (`--server-side=true`): kubectl sends the manifest to the API server, which computes the merge, applies the changes, and records field ownership.

Field ownership is metadata that tracks which manager (e.g., kubectl, Argo CD, a controller) owns each field of a resource. This enables conflict detection — for example, if one manager tries to modify a field currently owned by another, the API server can reject the change instead of silently overwriting it.

## TODO Prune

## Try it yourself

- Preview a change before committing to it: `kubectl diff -f manifest.yaml`.
- Swap `set selector` for `label` in the pipe-into-apply pattern — create a service with a custom label instead of a custom selector.
- Apply the same manifest twice with `--server-side`, then edit the live object directly with `kubectl edit` and re-apply — what does the conflict error look like, and what does `--force-conflicts` do?
- Compare `kubectl replace -f` against `kubectl apply -f` on the same manifest after editing a field out of it — which one removes the field, and which one leaves it?
- Use `kubectl explain deployment.spec.strategy` to find a field `kubectl create deployment` can't set, then add it via the `dry-run` + `patch` pipeline.
- Try `-o jsonpath='{.items[*].metadata.name}'` against `kubectl get pods` and compare it to `-o name`.
