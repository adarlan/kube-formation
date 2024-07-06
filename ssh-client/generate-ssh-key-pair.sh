#!/bin/bash
set -e
cd $(dirname $0)

echo; echo "## Generating SSH key pair"
(
    set -ex
    rm -f /secrets/id_rsa
    rm -f /secrets/id_rsa.pub
    ssh-keygen -t rsa -b 4096 -f /secrets/id_rsa -N ""
)
