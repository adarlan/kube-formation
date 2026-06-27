#!/bin/bash
set -euo pipefail

instance_ids="$(terraform output -json instance_ids)"
for id in $(echo "$instance_ids" | jq -r '.[]'); do
    aws ec2 start-instances --instance-ids $id
done
