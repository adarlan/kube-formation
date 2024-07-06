#!/bin/bash
set -e
cd $(dirname $0)

cmd="$@"

echo; echo "## Building Terraform image"; (
    set -ex
    docker build -t kube-formation/terraform -f Dockerfile .
)

echo; echo "## Running Terraform container"; (
    set -ex
    docker run -it --rm \
    -v $(pwd):/terraform -w /terraform \
    -v $(realpath ../secrets):/secrets \
    -u $(id -u):$(id -g) -v /etc/group:/etc/group:ro -v /etc/passwd:/etc/passwd:ro -v /etc/shadow:/etc/shadow:ro \
    kube-formation/terraform \
    $cmd
)
