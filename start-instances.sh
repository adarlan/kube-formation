#!/bin/bash
set -euo pipefail

nodes="$(terraform output -json nodes)"
for id in $(echo "$nodes" | jq -r '.[] | .instance_id'); do
    aws ec2 start-instances --instance-ids $id
done
