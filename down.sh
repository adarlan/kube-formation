#!/bin/bash
set -e

cd $(dirname $0)

(
    cd terraform

    set -ex
    terraform destroy
)

AMI_IDS=$(aws ec2 describe-images --region us-east-1 --owners self --filters "Name=name,Values=my-k8s-ami-*" --query 'Images[*].ImageId' --output text)

for AMI_ID in $AMI_IDS; do
  aws ec2 deregister-image --region us-east-1 --image-id $AMI_ID
done
