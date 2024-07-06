#!/bin/bash
set -e

export AWS_ACCESS_KEY_ID=$(cat /secrets/aws_access_key_id)
export AWS_SECRET_ACCESS_KEY=$(cat /secrets/aws_secret_access_key)
export AWS_DEFAULT_REGION=$(cat /secrets/aws_region)

AMI_IDS=$(aws ec2 describe-images --owners self --filters "Name=name,Values=my-k8s-ami-*" --query 'Images[*].ImageId' --output text)

for AMI_ID in $AMI_IDS; do
    (
        set -ex
        aws ec2 deregister-image --image-id $AMI_ID
    )
done
