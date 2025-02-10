#!/bin/bash
set -e
cd $(dirname $0)

aws_region=us-east-1

echo "[INFO] Fetching AMI IDs associated to this project"
ami_ids=$(aws ec2 describe-images \
    --region $aws_region \
    --owners self \
    --filters "Name=name,Values=my-k8s-ami-*" \
    --query 'Images[*].ImageId'
)
echo "$ami_ids" | jq

echo "$ami_ids" | jq -r '.[]' | while read -r ami_id; do

    echo "[INFO] Fetching EBS snapshot IDs associated to AMI: $ami_id"
    ebs_snapshot_ids=$(aws ec2 describe-images \
        --region $aws_region \
        --image-ids $ami_id \
        --query "Images[0].BlockDeviceMappings[*].Ebs.SnapshotId"
    )
    echo "$ebs_snapshot_ids" | jq

    echo "[INFO] Deregistering AMI: $ami_id"
    aws ec2 deregister-image \
        --region $aws_region \
        --image-id $ami_id

    echo "$ebs_snapshot_ids" | jq -r '.[]' | while read -r ebs_snapshot_id; do

        echo "[INFO] Deleting EBS snapshot: $ebs_snapshot_id"
        aws ec2 delete-snapshot \
            --region $aws_region \
            --snapshot-id $ebs_snapshot_id
    done
done
