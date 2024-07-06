#!/bin/bash
set -e
cd $(dirname $0)

export AWS_ACCESS_KEY_ID=$(cat /secrets/aws_access_key_id)
export AWS_SECRET_ACCESS_KEY=$(cat /secrets/aws_secret_access_key)
export AWS_DEFAULT_REGION=$(cat /secrets/aws_region)

export PACKER_PLUGIN_PATH=$(realpath .packer.d/plugins)

echo; echo "## Packer: Initializing configuration"; (
    set -ex
    cd kubernetes-node-ami
    packer init .
)

echo; echo "## Packer: Building Kubernetes node AMI"; (
    set -ex
    cd kubernetes-node-ami
    packer build node-image.pkr.hcl
)
