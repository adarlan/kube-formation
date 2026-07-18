# Grant cluster-level access for administrators

Kubernetes has no built-in User/Group objects — identity comes entirely from the `CN` (username) and `O` (group) fields on a client certificate signed by the cluster CA. Below, a `ClusterRole`+`ClusterRoleBinding` grants full access to a group, then a user gets a cert for that group via a `CertificateSigningRequest` so `kubectl` can authenticate as it.

```shell
# Create kubeadm-lab:cluster-admin role
cat <<EOF | kubectl create -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kubeadm-lab:cluster-admin
rules:
- apiGroups: ['*']
  resources: ['*']
  verbs: ['*']
- nonResourceURLs: ['*']
  verbs: ['*']
EOF

# Bind it to kubeadm-lab:cluster-admin group
cat <<EOF | kubectl create -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kubeadm-lab:cluster-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kubeadm-lab:cluster-admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: kubeadm-lab:cluster-admin
EOF
```

Prepare Jane's key and certificate:

```shell
# Create key
openssl genrsa -out jane.key 2048

# Create certificate signing request; O= must match the group in the ClusterRoleBinding above
openssl req -new -key jane.key -out jane.csr -subj "/CN=jane/O=kubeadm-lab:cluster-admin"

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
# Add Jane's credentials/context to kubeconfig (embedded, so the cert files aren't needed afterward), then switch to it
kubectl config set-credentials kubeadm-lab:jane --client-key jane.key --client-certificate jane.crt --embed-certs=true
kubectl config set-context kubeadm-lab:jane --cluster kubeadm-lab --user kubeadm-lab:jane

kubectl config use-context kubeadm-lab:jane

# Confirm identity and effective permissions as Jane
kubectl auth whoami
kubectl auth can-i --list
```

```shell
# Safe to remove now that the cert/key are embedded in kubeconfig
rm -f jane.key jane.csr jane.crt
```

# Grant namespace-level access for developers, application owners, etc...

For scoped access, a namespaced `Role`+`RoleBinding` grants a group access within a single namespace only — same CSR flow as above, but the group targets that namespace instead of the whole cluster.

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

# Create certificate signing request; O= must match the group in the RoleBinding above
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
# Add John's credentials/context (embedded, scoped to app3), then switch to it
kubectl config set-credentials kubeadm-lab:john --client-key john.key --client-certificate john.crt --embed-certs=true
kubectl config set-context kubeadm-lab:john --cluster kubeadm-lab --user kubeadm-lab:john --namespace app3

kubectl config use-context kubeadm-lab:john

# Confirm identity and effective permissions as John
kubectl auth whoami
kubectl auth can-i --list
```

```shell
# Safe to remove now that the cert/key are embedded in kubeconfig
rm -f john.key john.csr john.crt
```

```shell
# Get pods in app3 namespace
kubectl get pods

# Try to get pods in a different namespace (forbidden)
kubectl get pods -n default
```

## Try it yourself

- Switch back with `kubectl config use-context kubeadm-lab-admin` (or whatever your original context is named), then `kubectl config delete-context`/`delete-user` for Jane and John, and `kubectl delete clusterrole/clusterrolebinding kubeadm-lab:cluster-admin`, `kubectl delete ns app3` to tear everything down.
- What happens if you run `kubectl auth can-i --list` *before* approving the CSR, or after deleting the CSR object — does the already-issued cert still work?
- Try `kubectl auth can-i delete pods --as=john -n app3` (or `--as-group=app3`) from the admin context instead of switching contexts — compare with actually switching to John's context.
- Add a second user to the same `app3` group (different CN, same O=) and confirm they get identical permissions without touching the Role/RoleBinding.
- Shorten `expirationSeconds` on a CSR to something small (e.g. 60) and see what happens to `kubectl auth whoami` once the cert expires — is there a clean re-auth path, or do you need a brand-new CSR?
- Change John's Role to `verbs: ["get", "list", "watch"]` only and confirm `kubectl auth can-i delete pods` now returns `no`.
- Look up `kubectl create clusterrolebinding --dry-run=client -oyaml` and `kubectl create rolebinding` as a shorthand for the YAML blocks above.
