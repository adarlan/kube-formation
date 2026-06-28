#!/bin/bash
set -euo pipefail

ip="$(terraform output -json control_plane_nodes | jq -r '.controlplane1.public_ip')"

admin_conf="$(ssh -i private_key -o UserKnownHostsFile=known_hosts ubuntu@"$ip" "sudo cat /etc/kubernetes/admin.conf" | yq -o=json)"

echo "$admin_conf" | jq -r '.clusters[0].cluster["certificate-authority-data"]' | base64 --decode > ca.crt
echo "$admin_conf" | jq -r '.users[0].user["client-certificate-data"]' | base64 --decode > client.crt
echo "$admin_conf" | jq -r '.users[0].user["client-key-data"]' | base64 --decode > client.key

kubectl config set-cluster kube-formation --server "https://$ip:6443" --certificate-authority ca.crt --embed-certs=true
kubectl config set-credentials kube-formation --client-key client.key --client-certificate client.crt --embed-certs=true
kubectl config set-context kube-formation --cluster=kube-formation --user=kube-formation
kubectl config use-context kube-formation
