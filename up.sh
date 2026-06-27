#!/bin/bash
set -euo pipefail

source .env

packer init .
packer build ami.pkr.hcl

terraform init
terraform apply -auto-approve

./ssh-config.sh

ansible-playbook cluster.yml

kubectl get nodes
