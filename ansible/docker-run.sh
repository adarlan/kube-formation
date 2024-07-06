#!/bin/bash
set -e
cd $(dirname $0)

cmd="$@"

echo; echo "## Building Ansible image"; (
    set -ex
    docker build -t kube-formation/ansible -f Dockerfile .
)

echo; echo "## Running Ansible container"; (
    set -ex
    docker run -it --rm \
    -v $(pwd):/ansible -w /ansible \
    -v $(realpath ../secrets):/secrets \
    kube-formation/ansible \
    $cmd

    # TODO -u $(id -u):$(id -g) -v /etc/group:/etc/group:ro -v /etc/passwd:/etc/passwd:ro -v /etc/shadow:/etc/shadow:ro \
    # It does not work here because Ansible tries to create files in user home, but permission is denied
)
