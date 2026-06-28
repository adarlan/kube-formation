#!/bin/bash
set -euo pipefail

node="${1:?Usage: $0 <node-name>}"
ip="$(terraform output -json nodes | jq -r --arg node "$node" '.[$node].public_ip')"
ssh -i private_key -o UserKnownHostsFile=known_hosts ubuntu@"$ip"
