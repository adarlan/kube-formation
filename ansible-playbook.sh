#!/bin/bash
set -e
cd $(dirname $0)

control_plane_ip=$(terraform -chdir=terraform output -raw control_plane_ip)
worker_1_ip=$(terraform -chdir=terraform output -raw worker_1_ip)
worker_2_ip=$(terraform -chdir=terraform output -raw worker_2_ip)

terraform -chdir=terraform output -raw private_key > ./ansible/private_key
chmod 600 ./ansible/private_key

cat <<EOF > ./ansible/hosts
[controlplane]
controlplane0 ansible_host=$control_plane_ip
[workers]
worker1 ansible_host=$worker_1_ip
worker2 ansible_host=$worker_2_ip
EOF

rm -rf ./ansible/known_hosts
touch ./ansible/known_hosts
ssh-keyscan $control_plane_ip >> ./ansible/known_hosts
ssh-keyscan $worker_1_ip >> ./ansible/known_hosts
ssh-keyscan $worker_2_ip >> ./ansible/known_hosts
chmod 644 ./ansible/known_hosts

cd ansible

ansible-playbook \
    --private-key ./private_key \
    --ssh-extra-args "-o UserKnownHostsFile=./known_hosts" \
    --inventory ./hosts \
    --user ubuntu \
    playbook.yaml
