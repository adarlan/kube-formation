#!/bin/bash
set -e
cd $(dirname $0)

cd terraform
terraform init
terraform destroy -auto-approve
