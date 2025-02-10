#!/bin/bash
set -e
cd $(dirname $0)

cd ansible

ansible-playbook \
    --private-key ./private_key \
    --ssh-extra-args "-o UserKnownHostsFile=./known_hosts" \
    --inventory ./inventory \
    --user ubuntu \
    playbook.yaml
