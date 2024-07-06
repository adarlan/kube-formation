#!/bin/bash
set -e
cd $(dirname $0)

cmd="$@"

echo; echo "## Building Packer image"; (
    set -ex
    docker build -t kube-formation/packer -f Dockerfile .
)

echo; echo "## Running Packer container"; (
    set -ex
    docker run -it --rm \
    -v $(pwd):/packer -w /packer \
    -v $(realpath ../secrets):/secrets \
    -u $(id -u):$(id -g) -v /etc/group:/etc/group:ro -v /etc/passwd:/etc/passwd:ro -v /etc/shadow:/etc/shadow:ro \
    kube-formation/packer \
    $cmd
)
