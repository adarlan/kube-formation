
## Help and discovery

```shell
kubectl --help
kubectl options
kubectl api-resources ...
kubectl api-versions
kubectl explain ...
```

<!-- General
kubectl version
kubectl version --client

Configuration
kubectl config --help
kubectl config get-contexts
kubectl config current-context
kubectl config use-context
kubectl config view

Authentication / Cluster info
kubectl cluster-info
kubectl auth --help
kubectl auth can-i -->

## Create resources

Imperative:

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

Declarative:

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
kubectl create deployment foo --image=nginx --dry-run=client -oyaml > manifest.yaml
```

Then:

```shell
kubectl apply -f manifest.yaml
```

## Read resources

```shell
# List resources
kubectl get ...

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

# Detailed information
kubectl describe ...
```

## Update resources

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

## Delete resources

```shell
kubectl delete ...
```

## Troubleshooting

```shell
kubectl logs ...
kubectl exec ...
kubectl attach ...
kubectl cp ...
kubectl port-forward ...
kubectl debug ...
kubectl top ...
kubectl events ...
```
