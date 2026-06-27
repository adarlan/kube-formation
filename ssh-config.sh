#!/bin/bash
set -euo pipefail

echo "Configuring private key..."
terraform output -raw private_key > private_key
chmod 600 private_key

echo "Configuring known hosts..."
: > known_hosts
ips="$(terraform output -json ips)"
for ip in $(echo "$ips" | jq -r '.[]'); do
    echo "- $ip"
    ssh-keyscan $ip >> known_hosts
done
chmod 644 known_hosts

echo "Testing connection..."
ansible k8s -m ping
