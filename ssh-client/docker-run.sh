#!/bin/bash
set -e
cd $(dirname $0)

cmd="$@"

echo; echo "## Building SSH Client image"; (
    set -ex
    docker build -t kube-formation/ssh-client -f Dockerfile .
)

echo; echo "## Running SSH Client container"; (
    set -ex
    docker run -it --rm \
    -v $(pwd):/ssh-client -w /ssh-client \
    -v $(realpath ../secrets):/secrets \
    -u $(id -u):$(id -g) -v /etc/group:/etc/group:ro -v /etc/passwd:/etc/passwd:ro -v /etc/shadow:/etc/shadow:ro \
    kube-formation/ssh-client \
    $cmd
)
