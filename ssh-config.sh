#!/bin/bash
set -euo pipefail

echo "Configuring private key..."
terraform output -raw private_key > private_key
chmod 600 private_key

echo "Configuring known hosts..."
: > known_hosts
nodes="$(terraform output -json nodes)"
for ip in $(echo "$nodes" | jq -r '.[] | .public_ip'); do
    echo "- $ip"
    ssh-keyscan $ip >> known_hosts
done
chmod 644 known_hosts

echo "Generating Ansible inventory..."
control_plane_nodes="$(terraform output -json control_plane_nodes)"
worker_nodes="$(terraform output -json worker_nodes)"
{
    echo "[bootstrap_control_plane]"
    echo "$control_plane_nodes" | jq -r 'to_entries | first | "\(.key) ansible_host=\(.value.public_ip)"'
    echo ""
    echo "[control_plane]"
    echo "$control_plane_nodes" | jq -r 'to_entries[] | "\(.key) ansible_host=\(.value.public_ip)"'
    echo ""
    echo "[workers]"
    echo "$worker_nodes" | jq -r 'to_entries[] | "\(.key) ansible_host=\(.value.public_ip)"'
    echo ""
    echo "[k8s:children]"
    echo "control_plane"
    echo "workers"
    echo ""
    echo "[k8s:vars]"
    echo "ansible_user=ubuntu"
    echo "ansible_python_interpreter=/usr/bin/python3"
} > inventory.ini

echo "Testing connection..."
ansible k8s -m ping
