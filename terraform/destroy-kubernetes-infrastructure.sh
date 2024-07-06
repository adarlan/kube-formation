#!/bin/bash
set -e
cd kubernetes-infrastructure

export AWS_ACCESS_KEY_ID=$(cat /secrets/aws_access_key_id)
export AWS_SECRET_ACCESS_KEY=$(cat /secrets/aws_secret_access_key)
export AWS_DEFAULT_REGION=$(cat /secrets/aws_region)
export TF_VAR_ssh_public_key_file_path="/secrets/id_rsa.pub"

echo; echo "## Terraform: initializing Kubernetes infrastructure configuration"; (
    set -ex
    terraform init
)

echo; echo "## Terraform: destroying Kubernetes infrastructure"; (
    set -ex
    terraform destroy -auto-approve
)
