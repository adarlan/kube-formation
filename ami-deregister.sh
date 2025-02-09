#!/bin/bash
set -e
cd $(dirname $0)

ami_ids=$(aws ec2 describe-images \
    --region us-east-1 \
    --owners self \
    --filters "Name=name,Values=my-k8s-ami-*" \
    --query 'Images[*].ImageId' \
    --output text
)

for ami_id in $ami_ids; do
    echo "Deregistering AMI: $ami_id"
    aws ec2 deregister-image \
        --region us-east-1 \
        --image-id $ami_id
    # TODO Delete EBS snapshots created by CreateImage
    # Standard EBS snapshot storage pricing: $0.05/GB-month
    # These snapshots contain the following description:
    # "Created by CreateImage(INSTANCE_ID) for AMI_ID"
done
