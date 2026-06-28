#!/bin/bash
set -euo pipefail

terraform init
terraform apply

./ssh-config.sh

ansible-playbook prepare-nodes.yml
ansible-playbook create-cluster.yml

./update-kubeconfig.sh
