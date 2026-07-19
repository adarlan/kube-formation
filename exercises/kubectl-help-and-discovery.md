# kubectl Help and Discovery

Ways to find out what `kubectl` can do and what a resource's fields are, without leaving the terminal.

## General help

```shell
# Top-level list of command groups
kubectl --help

# Help for a specific command, incl. its flags (works on any subcommand)
kubectl get --help

# Flags that are valid on every kubectl command (e.g. --namespace, --context, -o)
kubectl options
```

## Discover API resources

`api-resources` lists the resource *types* the cluster supports; `api-versions` lists the API groups/versions backing them.

```shell
# List all resource types: name, shortnames, API group, namespaced, kind
kubectl api-resources

# Add the SUPPORTED-VERBS column (useful to check if a resource is read-only, etc)
kubectl api-resources -o wide

# Only cluster-scoped (namespaced=false) or only namespaced (namespaced=true) resources
kubectl api-resources --namespaced=false

# List every apiVersion (group/version) currently served by the API server
kubectl api-versions
```

## Explain resource fields

`explain` reads the live cluster's OpenAPI schema, so it always matches the actual API version running — not a fixed doc.

```shell
# Top-level fields + description for a resource
kubectl explain service

# Drill into a nested field
kubectl explain pod.spec.containers

# Print the entire field tree at once instead of drilling down field by field
kubectl explain deployment --recursive
```

## Try it yourself

- Run `kubectl explain pod.spec.containers.livenessProbe` — how deep does the tree go before it stops being useful?
- Compare `kubectl api-resources` output for a namespaced resource (e.g. `pods`) vs a cluster-scoped one (e.g. `nodes`) — which columns differ?
- Find a resource's shortname with `kubectl api-resources` (e.g. `po` for `pods`) and use it in a `kubectl get` command.
- Run `kubectl explain deployment --recursive` and pipe it into `less` — skim it before hand-writing your next manifest instead of guessing field names.
- Run `kubectl options` and try one of the listed global flags (e.g. `-v=6`) on a `get` command to see verbose request/response logging.
