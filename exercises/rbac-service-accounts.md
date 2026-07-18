
```shell
cat <<EOF | kubectl apply -f -
---
apiVersion: v1
kind: Namespace
metadata:
  name: app4
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app4
  namespace: app4
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app4
  namespace: app4
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["*"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app4
  namespace: app4
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: app4
subjects:
- kind: ServiceAccount
  name: app4
  namespace: app4
---
apiVersion: v1
kind: Pod
metadata:
  name: app4
  namespace: app4
spec:
  serviceAccountName: app4
  containers:
  - name: kubectl
    image: bitnami/kubectl:latest
    command:
    - /bin/sh
    - -c
    - sleep infinity
EOF
```

kubectl exec -it -n app4 pod/app4 -- sh

kubectl get pods
