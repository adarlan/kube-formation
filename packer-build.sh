#!/bin/bash
set -e
cd $(dirname $0)

cd packer
packer init .
packer build main.pkr.hcl
