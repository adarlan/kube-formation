#!/bin/bash
set -e
cd $(dirname $0)

cmd="$@"

echo; echo "## Building AWS CLI image"; (
    set -ex
    docker build -t kube-formation/aws-cli -f Dockerfile .
)

echo; echo "## Running AWS CLI container"; (
    set -ex
    docker run -it --rm \
    -v $(pwd):/aws-cli -w /aws-cli \
    -v $(realpath ../secrets):/secrets \
    -u $(id -u):$(id -g) -v /etc/group:/etc/group:ro -v /etc/passwd:/etc/passwd:ro -v /etc/shadow:/etc/shadow:ro \
    kube-formation/aws-cli \
    $cmd
)
