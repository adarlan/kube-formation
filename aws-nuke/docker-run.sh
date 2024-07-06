#!/bin/bash
set -e
cd $(dirname $0)

cmd="$@"

echo; echo "## Building AWS Nuke image"; (
    set -ex
    docker build -t kube-formation/aws-nuke -f Dockerfile .
)

echo; echo "## Running AWS Nuke container"; (
    set -ex
    docker run -it --rm \
    -v $(pwd):/aws-nuke -w /aws-nuke \
    -v $(realpath ../secrets):/secrets \
    -u $(id -u):$(id -g) -v /etc/group:/etc/group:ro -v /etc/passwd:/etc/passwd:ro -v /etc/shadow:/etc/shadow:ro \
    kube-formation/aws-nuke \
    $cmd
)
