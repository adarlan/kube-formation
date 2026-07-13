# Grant cluster-level access for administrators

```shell
# Create kube-formation:cluster-admin role
cat <<EOF | kubectl create -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kube-formation:cluster-admin
rules:
- apiGroups: ['*']
  resources: ['*']
  verbs: ['*']
- nonResourceURLs: ['*']
  verbs: ['*']
EOF

# Bind it to kube-formation:cluster-admin group
cat <<EOF | kubectl create -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kube-formation:cluster-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kube-formation:cluster-admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: kube-formation:cluster-admin
EOF
```

Prepare Jane's key and certificate:

```shell
# Create key
openssl genrsa -out jane.key 2048

# Create certificate signing request
openssl req -new -key jane.key -out jane.csr -subj "/CN=jane/O=kube-formation:cluster-admin"

cat <<EOF | kubectl create -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: jane
spec:
  request: $(openssl base64 -A -in jane.csr)
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400
  usages:
  - client auth
EOF

# Check its status (initially you'll see: CONDITION Pending)
kubectl get csr jane

# Approve it
kubectl certificate approve jane

# Check its status again (now you'll see: CONDITION Approved,Issued)
kubectl get csr jane

# Retrieve the signed certificate
kubectl get csr jane -o jsonpath='{.status.certificate}' | base64 -d > jane.crt
```

Configure Jane's kubectl:

```shell
kubectl config set-credentials kube-formation:jane --client-key jane.key --client-certificate jane.crt --embed-certs=true
kubectl config set-context kube-formation:jane --cluster kube-formation --user kube-formation:jane

kubectl config use-context kube-formation:jane

kubectl auth whoami
kubectl auth can-i --list
```

```shell
rm -f jane.key jane.csr jane.crt
```

# Grant namespace-level access for developers, application owners, etc...

```shell
# Create namespace
kubectl create ns app3

# Create role
cat <<EOF | kubectl create -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app3
  namespace: app3
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["*"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["*"]
EOF

# Create role binding
cat <<EOF | kubectl create -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app3
  namespace: app3
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: app3
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: app3
EOF
```

> Run `kubectl api-resources -owide` to see all API groups, resources, and verbs.

Prepare John's key and certificate:

```shell
# Create key
openssl genrsa -out john.key 2048

# Create certificate signing request
openssl req -new -key john.key -out john.csr -subj "/CN=john/O=app3"

cat <<EOF | kubectl create -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: john
spec:
  request: $(openssl base64 -A -in john.csr)
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400
  usages:
  - client auth
EOF

# Check its status (initially you'll see: CONDITION Pending)
kubectl get csr john

# Approve it
kubectl certificate approve john

# Check its status again (now you'll see: CONDITION Approved,Issued)
kubectl get csr john

# Retrieve the signed certificate
kubectl get csr john -o jsonpath='{.status.certificate}' | base64 -d > john.crt
```

Configure John's kubectl:

```shell
kubectl config set-credentials kube-formation:john --client-key john.key --client-certificate john.crt
kubectl config set-context kube-formation:john --cluster kube-formation --user kube-formation:john --namespace app3

kubectl config use-context kube-formation:john

kubectl auth whoami
kubectl auth can-i --list
```

```shell
rm -f john.key john.csr john.crt
```

```shell
# Get pods in app3 namespace
kubectl get pods

# Try to get pods in a different workspace (forbidden)
kubectl get pods -n default
```
