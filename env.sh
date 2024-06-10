#!/bin/bash
set -e

cd $(dirname $0)

source .env

export AWS_ACCESS_KEY_ID=$(aws --profile=$AWS_PROFILE configure get aws_access_key_id)
export AWS_SECRET_ACCESS_KEY=$(aws --profile=$AWS_PROFILE configure get aws_secret_access_key)

image=$(basename $(pwd)):$USER

user_id="$(id -u)"
group_id="$(id -g)"
docker build \
--file env.Dockerfile \
--tag $image \
--build-arg USER=$USER \
--build-arg UID=$user_id \
--build-arg GID=$group_id \
.

docker run -it --rm \
    -v $(pwd):/$(basename $(pwd)) -w /$(basename $(pwd)) \
    -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY \
    $image bash
