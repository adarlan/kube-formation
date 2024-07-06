#!/bin/bash
set -e
cd $(dirname $0)

control_plane_ip=$(cat /secrets/control_plane_ip)
worker_1_ip=$(cat /secrets/worker_1_ip)
worker_2_ip=$(cat /secrets/worker_2_ip)

# Create Ansible hosts file
cat <<EOF > hosts
[controlplane]
controlplane0 ansible_host=$control_plane_ip
[workers]
worker1 ansible_host=$worker_1_ip
worker2 ansible_host=$worker_2_ip
EOF

echo; echo "## Creating SSH known hosts file"; (
    set -ex
    rm -rf ssh_known_hosts
    touch ssh_known_hosts
    ssh-keyscan $control_plane_ip >> ssh_known_hosts
    ssh-keyscan $worker_1_ip >> ssh_known_hosts
    ssh-keyscan $worker_2_ip >> ssh_known_hosts
    chmod 644 ssh_known_hosts
)

# export ANSIBLE_HOME=$(realpath .ansible)

echo; echo "## Ansible: initializing Kubernetes cluster"; (
    set -ex
    ansible-playbook \
    --private-key /secrets/id_rsa \
    --ssh-extra-args "-o UserKnownHostsFile=./ssh_known_hosts" \
    --inventory hosts \
    --user ubuntu \
    playbook.yaml
)
