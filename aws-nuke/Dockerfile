FROM alpine:3.20

ENTRYPOINT [ "" ]

RUN apk update && apk add --no-cache \
curl bash

ARG AWS_NUKE_VERSION=2.25.0
RUN \
curl -fsSL https://github.com/rebuy-de/aws-nuke/releases/download/v${AWS_NUKE_VERSION}/aws-nuke-v${AWS_NUKE_VERSION}-linux-amd64.tar.gz -o - \
| tar -xz -C /usr/local/bin \
&& mv /usr/local/bin/aws-nuke-v${AWS_NUKE_VERSION}-linux-amd64 /usr/local/bin/aws-nuke \
&& chmod +x /usr/local/bin/aws-nuke
